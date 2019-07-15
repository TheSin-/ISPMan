
=head1 NAME
ISPMan::HostMan - Functions to manage Hosts



=head1 SYNOPSIS

   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


Some functions to read/write hosts and their group memberships


=cut

package ISPMan::HostMan;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  addHost
  addHostForm
  manageHosts
  getHosts
  editHost
  getHostInfo
  getHostIp
  add_host
  modify_host
  delete_host
  modifyHost
);
$VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->SUPER::register_handler( "testevent", "testhandler" );
}

sub addHost {

=item B<addHost>

Adds a new host to the list of ISPMan hosts, with the parameters
provided in the CGI-object $r.

usage

Have a cgi-form submit to ispman.cgi and be sure to set 'mode' to
'addHost', and submit values for hostname, ip, cn and description.

=cut

    my $self = shift;
    my $r    = shift;

    if (
        $self->add_host(
            $r->param('ispmanHostName'),  $r->param('ispmanHostIp'),
            $r->param('ispmanHostAlias'), $r->param('ispmanHostInfo')
        )
      )
    {
        $self->manageHosts();
    }
    else {
        $self->addHostForm();
    }
}

sub add_host {
    my $self = shift;
    if ( $self->{'session'} ) {
        return unless ( $self->{'session'}->param("logintype") eq "admin" );
        return unless $self->requiredAdminLevel(100);
    }
    my ( $hostname, $ip, $alias, $description ) = @_;

    if ( !$ip || !$hostname ) {
        print "ERROR: No hostname or ip specified";
        return 0;
    }

    my $data;
    $data->{'ispmanHostName'}  = $hostname;
    $data->{'ispmanHostIp'}    = $ip;
    $data->{'ispmanHostAlias'} = [ split( /\s+/, $alias ) ];
    $data->{'ispmanHostInfo'}  = $description || "undefined";
    $data->{'objectclass'}     = "ispmanHost";

    my $dn =
      "ispmanHostName=$hostname, ou=hosts, @{[$self->getConf('ldapBaseDN')]}";
    $self->addNewEntryWithData( $dn, $data );

    return 1;
}

sub modifyHost {
    my $self = shift;
    my $r    = shift;
    $self->modify_host(
        $r->param('ispmanHostName'),  $r->param('ispmanHostIp'),
        $r->param('ispmanHostAlias'), $r->param('ispmanHostInfo')
    );
    $self->manageHosts();
}

sub modify_host {
    my $self = shift;
    return unless $self->requiredAdminLevel(100);

    my ( $hostname, $ip, $alias, $description ) = @_;

    my $data;
    $data->{'ispmanHostIp'}    = $ip;
    $data->{'ispmanHostAlias'} = [ split( /\s+/, $alias ) ];
    $data->{'ispmanHostInfo'}  = $description || "undefined";

    my $dn =
      "ispmanHostName=$hostname, ou=hosts, @{[$self->getConf('ldapBaseDN')]}";
    $self->updateEntryWithData( $dn, $data );

#removing for the time being. will come back to this by 0.9
#$self->addProcessToGroup('ISPMAN_INTERNAL', "monitoringgroup", "AddHostToNetsaint",
#   join ',', ($hostname, $cn, $ip, $description, $hosttype)
#   ) if $self->getConf("useNetSaint");
}

sub delete_host {
    my $self = shift;

    if ( $self->{'session'} ) {
        return unless ( $self->{'session'}->param("logintype") eq "admin" );
        return unless $self->requiredAdminLevel(100);
    }

    my ($hostname) = @_;
    my $dn =
      "ispmanHostName=$hostname, ou=hosts, @{[$self->getConf('ldapBaseDN')]}";

    $self->deleteEntry($dn);
    $self->manageHosts();
}

sub getHostInfo {
    my $self       = shift;
    my ($hostname) = @_;
    my $hostinfo   =
      $self->getEntryAsHashRef(
        "ispmanHostName=$hostname, ou=hosts, @{[$self->getConf('ldapBaseDN')]}"
      );
    return $hostinfo;
}

sub getHostIp {
    my $self     = shift;
    my $hostinfo = $self->getHostInfo(@_);
    return $hostinfo->{'ispmanHostIp'};
}

sub getHosts {
    my $self = shift;
    return $self->getEntriesAsHashRef(
        "ou=hosts,  @{[$self->getConf('ldapBaseDN')]}",
        "objectclass=ispmanHost" );
}

sub addHostForm {
    my $self       = shift;
    my ($hostname) = @_;
    my $template   = $self->getTemplate("hosts/addHost.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub editHost {
    my $self       = shift;
    my ($hostname) = @_;
    my $template   = $self->getTemplate("hosts/editHost.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub manageHosts {
    my $self = shift;
    return unless $ENV{'HTTP_USER_AGENT'};

    my $template = $self->getTemplate("hosts/manageHosts.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

1;
__END__

