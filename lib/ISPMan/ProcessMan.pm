package ISPMan::ProcessMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  editProcess
  modifyProcess
  modifyDnsProcess
  getGroupMembers
  getPid
  deleteProcesses
  deleteProcessByPID
  deleteProcess_web
  addProcessToHost
  addProcessToGroup
  manageProcesses
  getProcesses
  updateProcess
  getProcessesForHost
  releaseSession
  releaseSession_web
  countProcessesInSession
  getProcessesBranchDN
  getSessionBranchDN
  getPidDN
);

$VERSION = '0.01';

sub getProcessesBranchDN {
    my $self = shift;
    return join ",", ( "ou=processes", $self->{'Config'}{'ldapBaseDN'} );
}

sub getSessionBranchDN {
    my $self     = shift;
    my $_session = shift;

    return join ",",
      ( "ispmanSession=$_session", $self->getProcessesBranchDN() );
}

sub getPidDN {
    my $self     = shift;
    my $_session = shift;
}

sub getPid {
    my $self  = shift;
    my $entry =
      $self->getEntry(
        "cn=pidcounter, ou=counters, @{[$self->getConf('ldapBaseDN')]}",
        "objectclass=ispmanCounters", ["ispmanCurrPid"] );
    my $pid = $entry->get_value("ispmanCurrPid");
    $self->updateEntryWithData(
        "cn=pidcounter, ou=counters, @{[$self->getConf('ldapBaseDN')]}",
        { "ispmanCurrPid" => ++$pid } );
    return $pid;
}

sub modifyDnsProcess {
    my $self   = shift;
    my $domain = shift;
    $self->addProcessToGroup( $domain, "dnsgroup", "modifyDomain" );
}

sub deleteProcesses {
    my $self      = shift;
    my $processes = shift;
    for (@$processes) {
        $self->deleteEntry($_);
    }
}

sub deleteProcess_web {
    my $self = shift;
    my $r    = shift;
    return unless $self->requiredAdminLevel(30);

    my $dn =
        "ispmanPid="
      . $r->param("ispmanPid") . ","
      . $self->getSessionBranchDN( $r->param("ispmanSession") );
    $self->deleteProcesses( [$dn] );
    $self->manageProcesses($r);
}

sub addProcess {

    #Generic process add function
    my $self = shift;
}

sub addProcessToGroup {
    my $self = shift;
    my ( $domain, $group, $process, $params ) = @_;
    my @members = $self->getGroupMembers($group);
    foreach (@members) {
        $self->addProcessToHost( $domain, $_, $process, $params );
    }
}

sub addProcessToHost {

    #Generic process add process to a Host
    #Usage: addProcessToHost(domain_name, host_name, process, parameters);

    my $self = shift;
    my ( $domain, $hostname, $process, $params ) = @_;

    my $dn;
    my $data;
    my $pid = $self->getPid;

    my $branch;
    if ( $ENV{'HTTP_USER_AGENT'} ) {
        if ( $self->{'sessID'} ) {
            $branch =
"ispmanSession=$self->{'sessID'}, ou=processes, @{[$self->getConf('ldapBaseDN')]}";
        }
        else {
            $branch =
"ispmanSession=CONTROLPANEL-$domain, ou=processes, @{[$self->getConf('ldapBaseDN')]}";
        }
    }
    else {
        $branch =
"ispmanSession=CONSOLE, ou=processes, @{[$self->getConf('ldapBaseDN')]}";
    }

    $self->prepareBranchForDN($branch);

    $dn                       = "ispmanPid=$pid, $branch";
    $data->{'ispmanPid'}      = $pid;
    $data->{'ispmanProcess'}  = $process;
    $data->{'ispmanParams'}   = $params;
    $data->{'ou'}             = "processes";
    $data->{'objectclass'}    = ["ispmanProcesses"];
    $data->{'ispmanHostName'} = $hostname;
    $data->{'ispmanDomain'}   = $domain;
    if ( $ENV{'HTTP_USER_AGENT'} ) {

        if ( $self->{'sessID'} ) {
            $data->{'ispmanStatus'}  = "insession";
            $data->{'ispmanSession'} = $self->{'sessID'};
            $data->{'ispmanUser'}    = $self->{'REMOTE_USER'};
        }
        else {
            $data->{'ispmanStatus'}  = "new";
            $data->{'ispmanSession'} = "CONTROLPANEL-$domain";
            $data->{'ispmanUser'}    = $domain;
        }
    }
    else {
        $data->{'ispmanSession'} = "CONSOLE";
        $data->{'ispmanUser'}    = $ENV{'USER'}
          || "ConsoleUser without a USER set";
        $data->{'ispmanStatus'} = "new";
    }

    $self->addNewEntryWithData( $dn, $data );
}

sub updateProcess {
    my $self = shift;
    my ( $dns, $status, $message ) = @_;
    my @pids = $self->as_array($dns);

    for (@pids) {
        $self->updateEntryWithData( $_,
            { "ispmanStatus" => $status, "ispmanMessage" => $message } );
    }

    my $mailhash;
    $mailhash->{'from'}    = "ispman";
    $mailhash->{'to'}      = $self->getConf("rootEmail");
    $mailhash->{'subject'} = "ISPMan Process updated";

    $mailhash->{'data'} = "ispmanStatus: $status\n";
    $mailhash->{'data'} .= "ispmanMessage: $message\n\n";
    for (@pids) {
        $mailhash->{'data'} .= "pid: $_\n";
    }

    $self->sendmail($mailhash);

    print "Receiving ", join "\n", ( @$dns, $status, $message );

}

sub modifyProcess {
    my $self = shift;
    my $r    = shift;
    my $dn   =
        "ispmanPid="
      . $r->param("ispmanPid") . ","
      . $self->getSessionBranchDN( $r->param("ispmanSession") );

    $self->updateEntryWithData(
        $dn,
        {
            "ispmanStatus"   => $r->param("ispmanStatus"),
            "ispmanPid"      => $r->param("ispmanPid"),
            "ispmanHostName" => $r->param("ispmanHostName"),

        }
    );

    $self->manageProcesses($r);
}

sub getProcesses {
    my $self = shift;
    undef $self->{'filter'};
    $self->{'filter'} = shift;

    if (   $self->{'session'}->param("logintype") eq "reseller"
        or $self->{'session'}->param("logintype") eq "client" )
    {
        $self->{'searchFilter'} =
          sprintf( "&(objectclass=ispmanProcesses)(ispmanuser=%s)",
            $self->{'session'}->param("uid") );
    }
    else {
        $self->{'searchFilter'} = "&(objectclass=ispmanProcesses)";
    }

    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    my $processHash = $self->getEntriesAsHashRef( $self->getProcessesBranchDN(),
        $self->{'searchFilter'} );
    return $processHash;
}

sub getProcessesForHost {
    my $self  = shift;
    my @hosts = $self->as_array(@_);

    my $filter = join "", map { "(ispmanHostName=$_)" } @hosts;
    $filter = "&(objectclass=ispmanProcesses)(ispmanStatus=new)(|$filter)";
    my $processHash =
      $self->getEntriesAsHashRef( $self->getProcessesBranchDN(), $filter );
    return $processHash;

}

sub deleteProcessByPID {
    my $self  = shift;
    my $pid   = shift;
    my $entry = $self->getEntry( $self->getProcessesBranchDN(),
        "ispmanPid=$pid", [], "sub" );
    my $dn = $entry->dn();
    $self->deleteProcesses( [$dn] );
}

sub manageProcesses {
    my $self     = shift;
    my $template = $self->getTemplate("processes/manageProcesses.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub editProcess {
    my $self     = shift;
    my $template = $self->getTemplate("processes/editProcess.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub releaseSession {
    my $self      = shift;
    my $session   = shift;
    my $processes =
      $self->getEntriesAsHashRef( $self->getSessionBranchDN($session),
        "objectClass=ispmanProcesses" );

    for ( keys %$processes ) {
        $self->modifyAttribute( $_, "ispmanStatus", "new" );
    }
    
    return scalar(keys %$processes);
}

sub releaseSession_web {
    my $self    = shift;
    my $r       = shift;
    my $session = $r->param("session");
    $self->releaseSession($session) if $session;

    print "<script>self.location='" . $r->param("nextPage") . "'</script>";
}

sub countProcessesInSession {
    my $self    = shift;
    my $session = shift;
    return $self->getChildrenCount( $self->getSessionBranchDN($session) );
}

1;

__END__

