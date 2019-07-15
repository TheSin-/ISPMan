
=head1 NAME
ISPMan::ApacheMan- Takes care of apache vhosts creation/modification



=head1 SYNOPSIS

	don't use this module directly.
	use ISPMan instead.


   

=head1 DESCRIPTION


   This module manages vhosts related functions such as 
   addVhost
   deleteVhost
   updateVhost
   getVhostInfo
   getVhostCount
	addVhostProcess
   etc
   

   It only adds data to the LDAP directory.
   The actual vhosts.conf is done by ispman-agent or script ldap2apache


=head1 METHODS


=over 4

=cut

package ISPMan::ApacheMan;

use strict;
use HTML::Entities;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);
require Exporter;
@ISA = qw(ISPMan Exporter AutoLoader);
use ISPMan::ApacheMan::Redirects;
use ISPMan::ApacheMan::Acls;
use ISPMan::ApacheMan::Aliases;

push @EXPORT, @ISPMan::ApacheMan::Redirects::EXPORT;
push @EXPORT, @ISPMan::ApacheMan::Acls::EXPORT;
push @EXPORT, @ISPMan::ApacheMan::Aliases::EXPORT;

push @EXPORT, qw(
  getVhostsBranchDN
  getVhostDN
  getApacheVhosts
  createVhost
  editVhost
  updateVhost
  suspendVhost
  suspend_vhost
  unsuspendVhost
  unsuspend_vhost
  addVhost
  newVhost
  deleteVhost
  getVhostInfo
  getVhostCount
  getVhostsCount
  delete_vhost
  update_vhost
  addVhostProcess
  addVirtualHostDirectoriesProcess
  changeVhostPassword
  getVhostAttribute
  setVhostAttribute
);
$VERSION = '0.01';

sub editVhost {
    my $self = shift;
    my $r    = shift;

    $self->{'vhost'} = $self->getVhostInfo( $r->param("ispmanVhostName"),
        $r->param("ispmanDomain") );

    my $template;
    my $tmpl;
    my $text =
      $self->getTemplate("vhosts/edit_header.tmpl")
      ->fill_in( PACKAGE => "ISPMan" );

    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $tmpl =
          ( $r->param("section") )
          ? join "_", ( "edit", $r->param("section") )
          : "edit";
        $template = $self->getTemplate("vhosts/$tmpl\.tmpl");
    }
    else {
        $template = $self->getTemplate("vhosts/view.tmpl");
    }
    $text .= $template->fill_in( PACKAGE => "ISPMan" );
    print $text;
}

sub getApacheVhosts {
    my $self = shift;
    my $dn   = shift;

    unless ( $dn =~ /^(ispmanVhostName|ou=)/ ) {

        #its a domain name instead
        $dn = $self->getVhostsBranchDN($dn);
    }
    my $vhostsHash =
      $self->getEntriesAsHashRef( $dn, "objectclass=ispmanVirtualHost",
        ["ispmanVhostName"] );
    my $vhosts;
    for ( keys %$vhostsHash ) {
        $vhosts->{ $vhostsHash->{$_}{'ispmanVhostName'} } = $_;
    }
    return $vhosts;
}

sub updateVhost {
    my $self = shift;
    my $r    = shift;
    if ( $self->update_vhost($r) ) {
        $self->editVhost($r);
    }
}

sub suspendVhost {
    my $self = shift;
    my $r    = shift;
    if (
        $self->suspend_vhost(
            $r->param("ispmanDomain"),
            $r->param("ispmanVhostName")
        )
      )
    {
        $self->editVhost($r);
    }
}

sub unsuspendVhost {
    my $self = shift;
    my $r    = shift;
    if (
        $self->unsuspend_vhost(
            $r->param("ispmanDomain"),
            $r->param("ispmanVhostName")
        )
      )
    {
        $self->editVhost($r);
    }
}

sub suspend_vhost {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $dn = $self->getVhostDN( $domain, $vhost );
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'disabled', 'ispmanStatus' => "suspended" } );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );

    return 1;
}

sub unsuspend_vhost {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $dn = $self->getVhostDN( $domain, $vhost );
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'enabled', 'ispmanStatus' => "active" } );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );

    return 1;
}

sub update_vhost {
    my $self = shift;
    my $r    = shift;

    my $dn = $self->getVhostDN( $r->param("ispmanDomain"),
        $r->param("ispmanVhostName") );

    my $domain      = $r->param("ispmanDomain");
    my $domain_info = $self->getDomainInfo($domain);

    my $data = {};

    for (
        qw(ispmanVhostIpAddress ispmanVhostDocumentRoot ispmanVhostScriptDir
        FTPQuotaMBytes FTPStatus ispmanVhostStats ispmanVhostLogdir
        ispmanVhostStatdir)
      )
    {
        if ( defined $r->param($_) ) {
            $data->{$_} = $r->param($_);
        }
        else {
            $data->{$_} = "";
        }
    }

    $data->{'ispmanVhostExtraConf'} =
      HTML::Entities::encode( $r->param("ispmanVhostExtraConf") );

    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $r->param("userPassword"),
        $self->getConf('userPassHashMethod') );

    #update the objectclasses if they are different
    $data->{'objectClass'} = $self->{'Config'}{'ispmanVhostObjectclasses'};

    for (qw(ispmanVhostDocumentRootOption ispmanVhostScriptDirOption ispmanVhostFeature)) {
        if ( $r->param($_) ) {
            $data->{$_} = [ $r->param($_) ];
        }
        else {
            $data->{$_} = "";
        }
    }

    if ( $self->{'ldap'}->updateEntryWithData( $dn, $data ) ) {
        $self->addVhostProcess(
            $r->param("ispmanDomain"), $r->param("ispmanVhostName"),
            "ModifyVirtualHost",       "ispmanVhostName=" . $r->param("ispmanVhostName")
        );
    }

    return 1;
}

sub createVhost {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    my $template;

    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );

    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("vhosts/add.tmpl");
    }
    else {
        $template = $self->getTemplate("ro.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub newVhost {
    my $self = shift;
    my $r    = shift;
    if ( $self->addVhost($r) ) {
        print $self->refreshSignal( $r->param("ispmanDomain") );
        $self->editVhost($r);
    }
}

sub addVhost {
    my $self = shift;
    my $r    = shift;

    # split vhostname into vhost and port
    my ( $vhost, $port ) = split ":", $r->param("ispmanVhostName");

    # filter for invalid chars
    $vhost = lc($vhost);
    $vhost =~ s/[^a-zA-Z0-9\.-]//g;
    $port  =~ s/[^0-9]//g;

    $r->param( "ispmanVhostName", $vhost . ( $port ? ":$port" : "" ) );

    my $domain = $r->param("ispmanDomain");

    # save domain info for use in template
    my $domain_info = $self->getDomainInfo($domain);
    if ($domain_info) {
        $r->param( "domain_info", $domain_info );
    }
    else {
        print "Domain \"$domain\" does not exist!\n";
        return 0;
    }

    # determine DN for new vhost
    my $dn = $self->getVhostDN( $domain, $r->param("ispmanVhostName") );
    $r->param( "dn", $dn );

    #check homeDirectory for reseller/client
    if (   $self->{'session'}
        && $self->{'session'}->param("logintype") =~ m/reseller|client/ )
    {
        my $domainHomeDirectoryPath = $domain_info->{"homeDirectory"};
        if ( $r->param("homeDirectory") &&
             $r->param("homeDirectory") !~ m/^$domainHomeDirectoryPath/ ) {
            print "Add Vhost aborted!\n".
                "HomeDirectory must be subdir of $domainHomeDirectoryPath.\n";
            return;
        }
    }

    # check vhost limit
    my $domainMaxVhosts =
      $self->getDomainAttribute( $domain, "ispmanMaxVhosts" );
    my $domainVhostCount = $self->getVhostCount($domain);
    if ( $domainMaxVhosts > 0 && $domainVhostCount >= $domainMaxVhosts ) {
        $self->{'message'} =
"Max vhosts limit exceeded. <br>Your limit is $domainMaxVhosts <br>You cannot create any more vhosts.";
        print $self->{'message'};
        return;
    }

    # check for defined webhosts
    my @webhosts;
    if ( $r->param("webHost") ) {
        @webhosts = $self->as_array( $r->param("webHost") );
    }
    else {

        # if caller didn't provide webhost we use the default for this domain
        @webhosts = $self->getDefaultWebHost($domain);
        $r->param( "webHost", @webhosts );
    }

    # finaly check if webhosts are set
    if ( $#webhosts < 0 ) {
        print "The webhost for "
          . $r->param("ispmanVhostName")
          . " cannot be determined!<br>Please check DefaultFileHost for domain $domain!\n";
        return;
    }

    # fill dir options if unset
    if ( !$r->param("ispmanVhostDocumentRootOption") ) {
        my @selected_options = ();
        for ( split ",", $self->getConf("apacheDocumentRootOptions") ) {
            if ( $_ =~ s/\*// ) { push @selected_options, $_ }
        }
        $r->param( "ispmanVhostDocumentRootOption", @selected_options );
    }
    if ( !$r->param("ispmanVhostScriptDirOption") ) {
        my @selected_options = ();
        for ( split ",", $self->getConf("apacheScriptDirOptions") ) {
            if ( $_ =~ s/\*// ) { push @selected_options, $_ }
        }
        $r->param( "ispmanVhostScriptDirOption", @selected_options );
    }

    # prepare DIT for new vhost DN
    $self->prepareBranchForDN( $self->getVhostsBranchDN($domain) );

    # write data to LDAP via template
    $self->addDataFromLdif( "templates/vhost.ldif.template", $r );

    # read back vhost entry to fill processes
    my $vhost_info =
      $self->getVhostInfo( $r->param("ispmanVhostName"), $domain );

    # add new A-record for webhost(s) if domain is primary
    if ( $domain_info->{'ispmanDomainType'} eq "primary" ) {
        if ( $#webhosts == 0 ) {

            # only single webhost is defined
            # (use webhost's IP if no explicit was supplied)
            my $ip = (
                (
                    !$r->param("ispmanVhostIpAddress")
                      || $r->param("ispmanVhostIpAddress") eq "*"
                )
                ? $self->getHostIp( $webhosts[0] )
                : $r->param("ispmanVhostIpAddress")
            );
            $self->addVhostDNSRecord( $r->param("ispmanDomain"), $vhost, $ip );
        }
        else {

            # multiple webhosts are defined
            # (apacheVhostsVIP overrides webhost ips)

            if ( $self->getConf("apacheVhostsVIP") =~
                /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ )
            {
                $self->addVhostDNSRecord( $r->param("ispmanDomain"),
                    $vhost, $self->getConf("apacheVhostsVIP") );
            }
            else {

                # this will create multiple a-records which
                # will act as simple round-robin loadbalancing.
                # Change them manually for proper hardware loadbalancing!
                for (@webhosts) {
                    $self->addVhostDNSRecord( $r->param("ispmanDomain"),
                        $vhost, $self->getHostIp($_) );
                }
            }
        }
    }

    # add process for each webhost
    for (@webhosts) {
        $self->addProcessToHost( $r->param("ispmanDomain"),
            $_, "AddVirtualHost", "ispmanVhostName=" . $r->param("ispmanVhostName") );
    }

    # add process for vhost directory creation
    $self->addVirtualHostDirectoriesProcess(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        "AddVirtualHostDirectories",
        join "&", map {"$_=$vhost_info->{$_}"} ("ispmanVhostName", "homeDirectory", "ispmanVhostDocumentRoot", "ispmanVhostScriptDir", "uidNumber", "gidNumber", "ispmanVhostLogdir", "ispmanVhostStatdir")
    );
    # add process for vhost actions
    if ( $r->param("vhostActions") ) {
	for ( $r->param("vhostActions") ) {
		$self->addVirtualHostDirectoriesProcess(
		$r->param("ispmanDomain"),
		$r->param("ispmanVhostName"),
		"execVhostActions",
		"script=$_" . "&uidNumber=" . $vhost_info->{"uidNumber"} 
		);
	}
    }
 return 1;
}

sub getVhostDN {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    return join ",",
      ( "ispmanVhostName=$vhost", $self->getVhostsBranchDN($domain) );

}

sub getVhostsBranchDN {
    my $self   = shift;
    my $domain = shift;
    return join( ",",
        "ou=httpdata", "ispmanDomain=$domain", $self->getConf('ldapBaseDN') );
}

sub delete_vhost {
    my $self = shift;
    my ( $ispmanVhostName, $ispmanDomain ) = @_;
    my $dn = $self->getVhostDN( $ispmanDomain, $ispmanVhostName );
    if ( $self->branchExists($dn) ) {
        my $vhostInfo  = $self->getVhostInfo( $ispmanVhostName, $ispmanDomain );
        my $domainInfo = $self->getDomainInfo($ispmanDomain);

        # first we add the process to delete the directories
        $self->addVirtualHostDirectoriesProcess(
            $ispmanDomain,
            $ispmanVhostName,
            "DeleteVirtualHostDirectories",
            join "&", map {"$_=$vhostInfo->{$_}"} qw (ispmanVhostName homeDirectory ispmanVhostDocumentRoot ispmanVhostScriptDir ispmanVhostLogdir ispmanVhostStatdir)
        );

        $self->addVhostProcess(
            $ispmanDomain,       $ispmanVhostName,
            "DeleteVirtualHost", "ispmanVhostName=$ispmanVhostName"
        );

        # Delete the A Record from DNS for this vhost
        # It will only be deleted if it was added bythis vhost process
        if ( $self->deleteVhostDNSRecord( $ispmanDomain, $ispmanVhostName ) >=
            0 )
        {
            $self->modifyDnsProcess($ispmanDomain);
        }

        if ( $self->delTree($dn) ) {
            return 1;
        }
    }
    else {
        print "Vhost $ispmanVhostName does not exists under $ispmanDomain\n";
    }

}

sub deleteVhost {
    my $self = shift;
    my $r    = shift;
    if (
        $self->delete_vhost(
            $r->param("ispmanVhostName"),
            $r->param("ispmanDomain")
        )
      )
    {
        print $self->refreshSignal( $r->param("ispmanDomain") );
        print "Virtualhost ", $r->param("ispmanVhostName"),
          " scheduled for deletion";
        return 1;
    }
    else {
        print "Error: ISPMan::ApacheMan::deleteVhost. Could not delete entry ";
    }
}

sub getVhostInfo {

=item B<getVhostInfo>

returns a hash with information about virtualhost


usage

Example:

my $vhostInfo=$ispman->getVhostInfo("www", "apache.org");


=cut

    my $self            = shift;
    my $ispmanVhostName = shift;
    my $domain          = shift;

    my $dn =
        "ispmanVhostName=$ispmanVhostName,"
      . "ou=httpdata,ispmanDomain=$domain,"
      . $self->getConf("ldapBaseDN");

    #uncomment this block  if you want it to cache the result
    #unless ($self->{'vhostInfo'}{$domain}{$ispmanVhostName}){
    $self->{'vhostInfo'}{$domain}{$ispmanVhostName} =
      $self->getEntryAsHashRef($dn);

    #}
    return $self->{'vhostInfo'}{$domain}{$ispmanVhostName};
}

sub getVhostsCount {
    my ($self) = @_;
    return $self->getCount( $self->getConf('ldapBaseDN'),
        "&(objectclass=ispmanVirtualHost)" );
}

sub getVhostCount {

=item B<getVhostCount>

	Returns number of vhosts in a domain.
	
	Accepts domain name as argument.

	example:

	print $ispman->getVhostCount("developer.ch");

=cut

    my $self   = shift;
    my $domain = shift;
    my $base   = join ",",
      ( "ou=httpdata", "ispmanDomain=$domain", $self->getConf("ldapBaseDN") );
    return $self->getCount( $base, "objectclass=ispmanVirtualHost" );
}

sub addVhostProcess {
    my $self = shift;
    my ( $domain, $vhost, $process, $param ) = @_;
    my $vhostInfo = $self->getVhostInfo( $vhost, $domain );
    my @webHosts  = $self->as_array( $vhostInfo->{'webHost'} );

    unless (@webHosts) {

        # if no webhosts are defined get defaults from domain
        my @webhost = $self->getDefaultWebHost($domain);
    }

    # if still no webhost are defined, warn user and bail out
    unless (@webHosts) {
        print qq[
No default webhost(s) could be determined.
You cannot add vhosts until you define some hosts in the httpgroup
];
        return 0;
    }

    foreach (@webHosts) {
        $self->addProcessToHost( $domain, $_, $process, $param );
    }

    return 1;
}

sub addVirtualHostDirectoriesProcess {

    # The admin can choose where the files for this vhost live.
    # The can be on the fileserver, webserver etc.
    # so according to fileHost, we
    # create web directory
    # delete web direcory

    my $self = shift;
    my ( $domain, $vhost, $process, $param ) = @_;
    my $vhostInfo = $self->getVhostInfo( $vhost, $domain );

    if ( $vhostInfo->{'fileHost'} ) {
        $self->addProcessToHost( $domain, $vhostInfo->{'fileHost'},
            $process, $param );
    }
    else {
        $self->addProcessToGroup( $domain, 'fileservergroup', $process,
            $param );
    }
}

sub changeVhostPassword {
    my $self = shift;
    my ( $vhost, $domain, $pass ) = @_;

    my $dn = $self->getVhostDN( $domain, $vhost );

    my $data = {};
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    return $self->updateEntryWithData( $dn, $data );
}

sub getVhostAttribute {
    my $self = shift;
    my ( $domain, $vhost, $attribute ) = @_;
    my $dn = $self->getVhostDN( $domain, $vhost );
    return unless $self->entryExists($dn);

    my $entry = $self->getEntry( $dn, 'objectclass=*', $attribute );

    return $self->get_attr_value( $entry, $attribute );

}

sub setVhostAttribute {
    my $self = shift;
    my ( $domain, $vhost, $attribute, @values ) = @_;
    my $value = $self->as_arrayref(@values);
    my $dn = $self->getVhostDN( $domain, $vhost );
    $self->modifyAttribute( $dn, $attribute, $value );
}

1;

__END__

