
=head1 NAME
ISPMan::DomainMan - Takes care of domain creation/modification



=head1 SYNOPSIS

   This is the master domain module.
   It is further split into
     ISPMan::DomainMan::PrimaryDomain;
     ISPMan::DomainMan::SlaveDomain;
     ISPMan::DomainMan::ReplicaDomain;
     ISPMan::DomainMan::NoDNSDomain;
   

=head1 DESCRIPTION


   This module manages domain related functions such as 
   addDomain
   deleteDomain
   modifyDomain
   getDomainInfo
   etc
   


=head1 METHODS


=over 4

=cut

package ISPMan::DomainMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
use ISPMan::DomainMan::PrimaryDomain;
use ISPMan::DomainMan::SlaveDomain;
use ISPMan::DomainMan::ReplicaDomain;
use ISPMan::DomainMan::NoDNSDomain;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(

  summary

  domainHasService
  checkDomainType
  getDomainType
  makeDomainHash
  getDomains
  getDomainInfo
  selectDomainType
  editDomain
  newDomain
  addDomain
  deleteDomain
  delete_domain
  suspend_domain
  unsuspend_domain
  getDomainGid
  getDomainsWithService
  getPrimaryDomains
  getSlaveDomains
  getReplicaDomains
  getNodnsDomains
  gotoEditDomain
  getReplicaCountForDomain
  getReplicasOfDomain
  modifySlaveDomain
  modifyReplicaDomain
  modifyPrimaryDomain
  modifyNoDNSDomain
  genericModifyDomain
  getTransportMap
  getDomainAttribute
  setDomainAttribute
  setMailTransport
  getDomainsCount
  isWebmailEnabled
  isDomainEditable
  isDomainLocked
  domainLockedBy
  lockDomain
  unlockDomain
  makeDomainDN
  getDomainAsDCObject
  prepareDNSBranch
  getDomainDN
  domainExists
  addDomainFileServerProcess
  addDomainSMTPProcess
  addDomainDNSProcess
  changeDomainPassword
  getDefaultFileHost
  getDefaultMailHost
  getDefaultWebHost
);

$VERSION = '0.01';

sub addDomainDNSProcess {
    my $self = shift;
    my ( $domain, $process, $param ) = @_;
    my $domainInfo = $self->getDomainInfo($domain);
    if ( $domainInfo->{'dnsHost'} ) {
        my @dnsHosts = $self->as_array( $domainInfo->{'dnsHost'} );
        for (@dnsHosts) {
            $self->addProcessToHost( $domain, $_, $process, $param );
        }
    }
    else {
        $self->addProcessToGroup( $domain, 'dnsgroup', $process, $param );
    }
}

sub addDomainFileServerProcess {
    my $self = shift;
    my ( $domain, $process, $param ) = @_;
    my $domainInfo = $self->getDomainInfo($domain);
    if ( $domainInfo->{'ispmanDomainDefaultFileServer'} ) {
        $self->addProcessToHost( $domain,
            $domainInfo->{'ispmanDomainDefaultFileServer'},
            $process, $param );
    }
    else {
        $self->addProcessToGroup( $domain, 'fileservergroup', $process,
            $param );
    }
}

sub addDomainSMTPProcess {
    my $self = shift;
    my ( $domain, $process, $param ) = @_;
    my $domainInfo = $self->getDomainInfo($domain);
    if ( $domainInfo->{'smtpHost'} ) {
        my @smtpHosts = $self->as_array( $domainInfo->{'smtpHost'} );
        for (@smtpHosts) {
            $self->addProcessToHost( $domain, $_, $process, $param );
        }
    }
    else {
        $self->addProcessToGroup( $domain, 'smtpgroup', $process, $param );
    }
}

##############################################################

=item B<addDomain> ($r)

$r is CGI.pm object passed from the CGI.

Add a new domain to ISPMan repository, which can be of the
types "primary", "slave", "nodns" and "replica".

Adds different processes to the process tree.

=cut

sub addDomain {
    my $self = shift;
    my $r    = shift;

    # some compliance modifications
    my $domain = lc( $r->param("ispmanDomain") );
    $domain =~ s/\s//g;
    $r->param( "ispmanDomain", $domain );

    # do some checks for resellers/clients
    if (   $self->{'session'}
        && $self->{'session'}->param("logintype") =~ m/reseller|client/ )
    {

        # check if reseller/client has reached domain limit
        my $ispmanClientInfo =
          $self->getClientById( $r->param("ispmanClientId") );
        my $ispmanClientMaxDomainsLimit =
          $ispmanClientInfo->{'ispmanClientMaxDomains'};
        my $ispmanClientDomains =
          $self->getDomainsCount(
            sprintf( "ispmanClientId=%s", $r->param("ispmanClientId") ) );

        unless ( $ispmanClientDomains < $ispmanClientMaxDomainsLimit ) {
            $self->{'message'} = "Max domains limit reached. Domain not added";
            print $self->{'message'};
            return;
        }

        # check if homeDirectory lies in defaultHomeDirectoryPath
        my $defaultHomeDirectoryPath =
          $self->getConf("defaultHomeDirectoryPath");
        if (    $r->param("ispmanDomainType") ne "replica"
            and $r->param("homeDirectory") !~ m/^$defaultHomeDirectoryPath/ )
        {
            print "Add Domain aborted!\nHomeDirectory '"
              . $r->param("homeDirectory")
              . "' must be subdir of $defaultHomeDirectoryPath.\n";
            return;
        }
    }

    return if $self->domainExists( $r->param("ispmanDomain") );

    # find reseller if clientId is set
    if ( $r->param("ispmanClientId") ) {
        $r->param(
            "ispmanResellerId",
            $self->getClientAttributeById(
                $r->param("ispmanClientId"),
                "ispmanResellerId"
            )
        );
    }

    # set reseller/client ids (from reseller/client session)
    if ( $self->{'session'} ) {
        if ( $self->{'session'}->param("logintype") eq "reseller" ) {
            $r->param( "ispmanResellerId",
                $self->{'session'}->param("ispmanResellerId") );
        }
        elsif ( $self->{'session'}->param("logintype") eq "client" ) {
            $r->param( "ispmanResellerId",
                $self->{'session'}->param("ispmanResellerId") );
            $r->param( "ispmanClientId",
                $self->{'session'}->param("ispmanClientId") );
        }
    }

    # assign new uidnumber/gidnumber
    $r->param( "uidnumber", $self->getUid() );
    $r->param( "gidnumber", $self->getGid() );

    # load common domain template
    $self->addDataFromLdif( "templates/domain.common.ldif.template", $r );

    # which templates are needed for what domain types
    my $ou = {
        'primary' => [ "dnszone", "posixGroup" ],
        'slave'   => ["posixGroup"],
        'nodns'   => ["posixGroup"],
        'replica' => [],
    };

    # load all needed templates
    for $ou ( @{ $ou->{ $r->param("ispmanDomainType") } } ) {
        $self->addDataFromLdif( "templates/domain.$ou.ldif.template", $r );
    }

    # add processes if this is a replica domain
    if ( $r->param("ispmanDomainType") eq "replica" ) {

        # Add entry for canonical map
        $self->addDomainSMTPProcess( $r->param("ispmanDomain"),
            "AddCanonicalMapEntry",
            "ispmanReplicaMaster=" . $r->param("ispmanReplicaMaster") );

        # Update ServerAliases for vhosts of MasterDomain
        my $vhosts = $self->getApacheVhosts( $r->param("ispmanReplicaMaster") );
        for my $vhost ( keys %$vhosts ) {
            $self->addVhostProcess( $r->param("ispmanReplicaMaster"),
                $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
        }
    }
    else {

        # Create directories for this domain
        # send the task to addDomainFileServerProcess.
        # It will add it to host or group
        # Give directory, uid, gid information
        my $_domainInfo = $self->getDomainInfo( $r->param("ispmanDomain") );

        $self->addDomainFileServerProcess(
            $r->param("ispmanDomain"),
            "createDomainDirectories",
            "homeDirectory=$_domainInfo->{'homeDirectory'}&uidNumber=$_domainInfo->{'uidNumber'}&gidNumber=$_domainInfo->{'gidNumber'}"
        );
    }

    # add domain to mail relay map for delivery method "smtp"
    if ( $r->param("ispmanDomainMailDeliveryMethod") eq "smtp" ) {
        $self->addDomainSMTPProcess( $r->param("ispmanDomain"),
            "AddRelayDomainEntry" );
    }
    else {

        # otherwise add domain to destination map
        $self->addDomainSMTPProcess( $r->param("ispmanDomain"),
            "AddDestinationDomainEntry" );
    }

    # domain service "db"
    if ( $r->param("ispmanDomainServices") =~ /db/ ) {

        # setup a database for this domain
        $self->addProcessToGroup( $r->param("ispmanDomain"),
            "dbgroup", "AddDomainDatabase" );
    }

    # reload nameserver
    unless ( $r->param("ispmanDomainType") eq "nodns" ) {
        $self->addDomainDNSProcess( $r->param("ispmanDomain"), "modifyDomain" );
    }

    print $self->refreshSignal( $r->param("ispmanDomain") );
    print "Domain ", $r->param("ispmanDomain"), " was added\n";

    # create process for domain actions
    if ( $r->param("domainActions") ) {
        for ( $r->param("domainActions") ) {
            $self->addDomainFileServerProcess( $r->param("ispmanDomain"),
                "execDomainActions", "script=$_" );
        }
    }

}

sub checkDomainType {
    my $self       = shift;
    my $domain     = shift;
    my $type       = shift;
    my $domaintype = $self->getDomainType($domain);
    if ( $domaintype !~ /$type/i ) {
        print "Sorry, this is not a $type domain.";
        return 0;
    }
    return 1;

=item B<checkDomainType>

Accepts $domain, $type

returns true if domain $domain is of type $type
returns false otherwise.

I<EXAMPLE>


$ispman->checkDomainType("domain.name","primary");


=cut

}

sub deleteDomain {
    my $self = shift;
    my $r    = shift;

=item B<deleteDomain>

Accepts $r,


B<IF this domain has replicas> then returns false printing an error message in HTML

B<ELSE>
   
=cut

    unless ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        my $template = $self->getTemplate("ro.tmpl");
        print $template->fill_in( PACKAGE => "ISPMan" );
        return;
    }

    if ( $self->{'session'} ) {

        # First Check.
        # Is this user Admin
        if ( $self->{'session'}->param("logintype") eq "admin" ) {

            # Need at least level 70 to be able to delete a domain
            ###
            return unless $self->requiredAdminLevel(70);
        }
    }

    # If there is no session, then the command is coming from CLI.
    # Let it through

    my $domain = $r->param("ispmanDomain");

    my $replicas = $self->getReplicasOfDomain($domain);
    if ($replicas) {
        print
          "<font size=+2 face=Arial><b>You cannot delete this domain.<br> It has other domains (replicas) depending on it.<br><br>";
        print "Delete the following domains before deleting this one<br>\n";
        print join "\n", map { "<li>$_</li>" } keys %$replicas;
        print "<br>";
        return;
    }

    $self->delete_domain($domain);

    print $self->refreshSignal();
}

sub delete_domain {
    my $self   = shift;
    my $domain = shift;

    return unless ( $self->isDomainEditable($domain) );

    return if $self->getReplicasOfDomain($domain);

    #Lets be a BOFH and Delete All users MuhhahhhAAAAhaahaa
    my $users = $self->getUsers($domain);

    for ( keys %$users ) {
        $self->killUser($_);
    }

    # delete all vhosts of domain
    my $vhosts = $self->getApacheVhosts($domain);
    for my $vhost ( keys %$vhosts ) {
        $self->delete_vhost( $vhost, $domain );
    }

    # delete all databases
    my $dbs = $self->getDatabases($domain);
    for my $db ( keys %$dbs ) {
        $self->delete_database( $db, $domain );
    }

    # Now Delete the rest of the tree.
    my $domain_info = $self->getDomainInfo( $domain, 1 );

    if ( $domain_info->{"ispmanDomainType"} eq "replica" ) {
        $self->addDomainSMTPProcess( $domain, "RemoveCanonicalMapEntry" );

        # Update ServerAliases for vhosts of MasterDomain
        my $vhosts =
          $self->getApacheVhosts( $domain_info->{"ispmanReplicaMaster"} );
        for my $vhost ( keys %$vhosts ) {
            $self->addVhostProcess( $domain_info->{"ispmanReplicaMaster"},
                $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
        }

    }
    else {

        # Delete directories for this domain
        # send the task to addDomainFileServerProcess.
        # It will add it to host or group
        $self->addDomainFileServerProcess(
            $domain,
            "deleteDomainDirectories",
            join '&',
            map { "$_=$domain_info->{$_}" }
              qw(homeDirectory uidNumber gidNumber)
        );
    }

    # Remove this domain from RelayDomains
    $self->addDomainSMTPProcess( $domain, "RemoveRelayDomainEntry" );

    # Remove from destination
    $self->addDomainSMTPProcess( $domain, "RemoveDestinationDomainEntry" );

    # Reload nameserver
    unless ( $domain_info->{"ispmanDomainType"} eq "nodns" ) {
        $self->addDomainDNSProcess( $domain, "modifyDomain" );
    }

    $self->delTree( $self->getDomainDN($domain) );

    #FIXME
    #this might also require a Process, not quite sure.

    $self->delTree( $self->getDNSDN($domain) );

    # Delete Domain PAB's
    $self->delTree(
        'ou=' . $domain . ',ou=pabs,' . $self->getConf("ldapBaseDN") );

}

sub domainExists {
    my $self   = shift;
    my $domain = shift;
    return $self->getCount( $self->getDomainDN($domain) );

=item B<domainExists>

   requires domain name
   
   returns true if the domain exists, and false if not
   

=cut

}

sub domainLockedBy {
    my $self   = shift;
    my $domain = shift;
    return $self->getDomainAttribute( $domain, "ispmanDomainLockedBy" );

}

sub editDomain {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param("ispmanDomain");
    $self->{'domain'} = $self->getDomainInfo($domain);

    my $domaintype = lc( $self->getDomainType($domain) );
    my $template   = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template =
          $self->getTemplate( "domains/edit_" . $domaintype . "_Domain.tmpl" );
    }
    else {
        $template = $self->getTemplate("domains/view_Domain.tmpl");
    }
    print $self->refreshSignal( $r->param("ispmanDomain") );
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<editDomain>

called from ispman.cgi

access $r as argument and loads the edit page for the type of the domain
specified


=cut

}

sub genericModifyDomain {
    my $self             = shift;
    my ($r)              = shift;
    my $oldDomainType=shift;
    my $newDomainType=$r->param("ispmanDomainType");

    my $domain      = $r->param("ispmanDomain");
    my $domain_info = $self->getDomainInfo($domain);
    my $dn          = $self->makeDomainDN($domain);
    my $data;

     my $ispmanDomainType;
     if ($newDomainType and ($newDomainType ne $oldDomainType)) {
        my $ou={
  	 'primary' => ["dnszone"],
  	 'slave'   => [],
  	 'nodns'   => [],
 	 'replica' => [],
        };
 
        for $ou (@{$ou->{$newDomainType}}){
 	 $self->addDataFromLdif("templates/domain.$ou.ldif.template", $r);
        }
 
        $ispmanDomainType=$newDomainType;
     } else {
        $ispmanDomainType=$oldDomainType;
     }

    $data->{'ispmanDomainType'} = $ispmanDomainType;
    if ( $ispmanDomainType ne "replica" ) {

        $data->{'uid'} = $domain;
        $data->{'userPassword'} =
          $self->encryptPassWithMethod( $r->param("userPassword"),
            $self->getConf('userPassHashMethod') );

        for (
            qw(homeDirectory ispmanDomainOwner ispmanDomainCustomer
            ispmanMaxAccounts ispmanMaxVhosts ispmanMaxDatabases ispmanDomainComment ispmanDnsMasters
            FTPStatus FTPQuotaMBytes
            ispmanDomainDefaultFileServer ispmanDomainDefaultMailDropHost ispmanDomainDefaultWebHost
            ispmanDomainService )
          )
        {
            $data->{$_} = $self->as_arrayref( $r->param($_) )
              if defined $r->param($_);
        }

        $data->{'ispmanDomainService'} = ""
          if ( !defined $r->param("ispmanDomainService") );

        $data->{'objectClass'} = $self->{'Config'}{'ispmanDomainObjectclasses'};

        if (   $r->param("ispmanDomainLocked")
            && $r->param("ispmanDomainLocked") eq "on" )
        {
            $data->{'ispmanDomainLockedBy'} = $self->{'REMOTE_USER'};
            $data->{'ispmanDomainLocked'}   = "true";
        }
        else {
            $data->{'ispmanDomainLockedBy'} = "";
            $data->{'ispmanDomainLocked'}   = "false";
        }

        unless ( $domain_info->{'uidNumber'} ) {

            #oops some old domain, no uidnumber. Lets add one.
            $data->{'uidNumber'} = $self->getUid();
        }
        unless ( $domain_info->{'gidNumber'} ) {

            #oops some old domain, no uidnumber. Lets add one.
            $data->{'gidNumber'} = $self->getGid();
        }
        unless ( $domain_info->{'loginShell'} ) {
            $data->{'loginShell'} = $self->getConf("loginShell");
        }

    }
    else {    # Replica
        $data->{'ispmanReplicaMaster'} = $r->param("ispmanReplicaMaster");
        $data->{'ispmanDomainComment'} = $r->param("ispmanDomainComment");
        $data->{'mailForwardingAddress'} =
          '@' . $r->param("ispmanReplicaMaster");
    }

    unless ( $domain_info->{'ispmanDomainMailDeliveryMethod'} eq
        $r->param("ispmanDomainMailDeliveryMethod") )
    {
        $data->{'ispmanDomainMailDeliveryMethod'} =
          $r->param("ispmanDomainMailDeliveryMethod");
    }

    # add changes to LDAP and generate processes
    if ( $self->{'ldap'}->updateEntryWithData( $dn, $data ) ) {

        # adjust mail maps when delivery method has changed
        if ( $data->{'ispmanDomainMailDeliveryMethod'} ) {

            $self->addDomainSMTPProcess( $domain, "modifyTransport",
                "ispmanDomainMailDeliveryMethod="
                  . $self->getTransportMap($domain) );

            if ( $domain_info->{'ispmanDomainMailDeliveryMethod'} eq "local" ) {
                $self->addDomainSMTPProcess( $domain,
                    "RemoveDestinationDomainEntry" );
                $self->addDomainSMTPProcess( $domain, "AddRelayDomainEntry" );
            }
            else {
                $self->addDomainSMTPProcess( $domain,
                    "RemoveRelayDomainEntry" );
                $self->addDomainSMTPProcess( $domain,
                    "AddDestinationDomainEntry" );
            }
        }

        if ( $ispmanDomainType eq "replica" ) {

            # ispmanReplicaMaster changed?
            if ( $domain_info->{'ispmanReplicaMaster'} ne
                $r->param("ispmanReplicaMaster") )
            {
                $self->addDomainSMTPProcess( $domain, "AddCanonicalMapEntry",
                    "ispmanReplicaMaster=" . $r->param("ispmanReplicaMaster") );
                $self->addDomainDNSProcess( $domain, "modifyDomain" );

                # Update ServerAliases for vhosts of old MasterDomain
                my $vhosts =
                  $self->getApacheVhosts(
                    $domain_info->{"ispmanReplicaMaster"} );
                for my $vhost ( keys %$vhosts ) {
                    $self->addVhostProcess(
                        $domain_info->{"ispmanReplicaMaster"},
                        $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
                }

                # Update ServerAliases for vhosts of new MasterDomain
                $vhosts =
                  $self->getApacheVhosts( $r->param("ispmanReplicaMaster") );
                for my $vhost ( keys %$vhosts ) {
                    $self->addVhostProcess( $r->param("ispmanReplicaMaster"),
                        $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
                }

            }
         }
	 unless ($ispmanDomainType eq $oldDomainType) {
	 # reload named
	 $self->addDomainDNSProcess($domain, "modifyDomain");
	
	}
        return 1;
    }
}

sub getDomainAsDCObject {
    my $self   = shift;
    my $domain = shift;
    return join ",", ( map { "dc=$_" } split( '\.', $domain ) );
}

sub getDomainAttribute {
    my $self = shift;

    my $domain = shift;
    my $attr   = shift;

    # FIXME: implement caching here
    # load domain data
    my $domaininfo = $self->getDomainInfo($domain);

    # get attrbitute (don't care about undef, return "" in that case)
    my $val = $domaininfo->{$attr} || "";

    # return what the caller wants
    if ( ref $val eq "ARRAY" ) {

        # attribute is an array, so return whole array or first element
        return wantarray ? @{$val} : $val->[0];
    }
    else {
        return $val;
    }

=item B<getDomainAttribute>

   requires domain name , attribute name
   
   returns the value(s) of the attribute for the domain.
   
   

I<EXAMPLE>


   use ISPMan;
   my $ispman=ISPMan->new();
   
   my $owner=$ispman->getDomainAttribute("ispman.org", "ispmanDomainOwner");
   print "Domain owner is $owner\n";
   
   
   

=cut

}

sub getDomainDN {
    my $self = shift;
    return $self->makeDomainDN(@_);

=item B<getDomainDN>

   requires domain name.
   
   return the DN of the domain.
   
   If you want the DN of the domain, use this method.
   Do not recreate the domain's DN by concatinating 
   ispmanDomain=name, ldapBaseDN
   

I<EXAMPLE>


   use ISPMan;
   my $ispman=ISPMan->new();
   my $dn=$ispman->getDomainDN('ispman.org');

=cut

}

sub getDomainGid {
    my $self       = shift;
    my $domain     = shift;
    my $domainInfo = $self->getDomainInfo($domain);
    return $domainInfo->{'gidNumber'};

=item B<getDomainGid>

returns GID (gidnumber)  of domain

I<EXAMPLE>

getDomainGid("domain.name");


=cut

}

sub getDomainInfo {
    my $self   = shift;
    my $domain = shift;

    $self->{'searchFilter'} = "objectclass=ispmanDomain";

    # Check if there is a session
    if ( $self->{'session'} ) {
        if ( $self->{'session'}->param("logintype") eq "reseller" ) {

            # A reseller should only be able to see the domains where
            # he is marked as the reseller
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanDomain)(ispmanResellerId=%s)",
                $self->{'session'}->param("ispmanResellerId") );
        }
        elsif ( $self->{'session'}->param("logintype") eq "client" ) {

            # A client should only be able to see the domains where
            # he is marked as the client
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanDomain)(ispmanClientId=%s)",
                $self->{'session'}->param("ispmanClientId") );
        }
    }

    #pass forget if you want fresh result, else you get cached result
    # FIXME: caching
    my $forget = shift;
    $forget = 1;

    my $dn = $self->makeDomainDN($domain);
    $self->{'domaininfo'}{$domain} =
      $self->getEntryAsHashRef( $dn, $self->{'searchFilter'} );

    return $self->{'domaininfo'}{$domain};

    # FIXME
    # the rest is crap. must be removed.
    # or it should be rethought.

    if ( $self->{'domaininfo'}{$domain} ) {

#if we were called with a positive value for $forget, we reget the information for this domian.
        if ($forget) {
            $self->{'domaininfo'}{$domain} = $self->getEntryAsHashRef($dn);
            $self->log_event(
                "getDomainInfo called for  $domain, returning info from LDAP")
              if $self->getConfig("debug") > 2;
        }
        else {
            $self->log_event(
                "getDomainInfo called for  $domain, returning CACHED info")
              if $self->getConfig("debug") > 2;
        }
    }
    else {
        $self->log_event("getDomainInfo called for  $domain, CACHING info")
          if $self->getConfig("debug") > 1;
        my $hr = $self->getEntriesAsHashRef( $self->getConf("ldapBaseDN"),
            "objectclass=ispmanDomain" );
        for ( keys %$hr ) {
            $self->{'domaininfo'}{ $hr->{$_}{'ispmanDomain'} } = $hr->{$_};
            $self->log_event("Caching info for $_")
              if $self->getConfig("debug") > 2;
        }
    }

    return $self->{'domaininfo'}{$domain};

=item B<getDomainInfo>

return infomations about a domain.

accepts domainName or a DN of a domain, 

I<EXAMPLE>

Getting domain info by passing a domain name
my $domInfo=$ispman->getDomainInfo("developer.ch");


Getting domain info by passing a domain's DN
my $domInfo=$ispman->getDomainInfo("ispmanDomain=developer.ch, o=4unet");

The first time this function is called, it searches the LDAP directory for 
all domains and caches the result. Every subsequent request gets a cached result. 
(slow for diconnected access , extremely fast with mod_perl)

You can pass optionally a positive value so that you don't get a cached result.

I<EXAMPLE>


Getting domain info by passing a domain name, requesting fresh result from LDAP
my $domInfo=$ispman->getDomainInfo("developer.ch", 1);
This will look in the ldap tree and return the result
even if there is a cached value

=cut

}

sub getDomainType {
    my $self       = shift;
    my $domain     = shift;
    my $domainInfo = $self->getDomainInfo($domain);
    return $domainInfo->{'ispmanDomainType'};

=item B<getDomainType>

returns type of domain (primary, slave, nodns or replica)
First call to this function is the slow one. cause it loads all types and caches them.

I<EXAMPLE>


getDomainType("domain.name");


=cut

}

sub getDomains {
    my $self = shift;
    undef $self->{'filter'};
    $self->{'filter'} = shift;
    my $attr = shift;

    unless ( defined $attr ) {
        $attr = [ "ispmanDomain", "ispmanDomainType" ];
    }

    $self->{'searchFilter'} = "&(objectclass=ispmanDomain)";

    if ( $self->{'session'} ) {
        if ( $self->{'session'}->param("logintype") eq "reseller" ) {
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanDomain)(ispmanResellerId=%s)",
                $self->{'session'}->param("ispmanResellerId") );
        }
        elsif ( $self->{'session'}->param("logintype") eq "client" ) {
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanDomain)(ispmanClientId=%s)",
                $self->{'session'}->param("ispmanClientId") );
        }
        elsif ( $self->{'session'}->param("logintype") eq "domain" ) {
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanDomain)(ispmanDomain=%s)",
                $self->{'session'}->param("ispmanDomain") );
        }
    }

    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    my $entries = $self->getEntriesAsHashRef( $self->{'Config'}->{'ldapBaseDN'},
        "$self->{'searchFilter'}", $attr );

    return $entries;

=item B<getDomains>

   returns concatenated result of 
   getPrimaryDomains
   getSlaveDomains
   getReplicaDomains
   getNoDnsDomains
   
   as a hashref

   B<NOTE> this function is changed.
   It now returns a hashref or Net::LDAP::Entries objects.
   
   If you want the old behaviour use makeDomainHash(getDomains()) format
   
   
I<EXAMPLE>


   use ISPMan;
   my $ispman=ISPMan->new();
   $domains=$ispman->getDomains();
   for (keys %$domains) {
      print "$\n";
   }

   this will print something like
   domain1.com
   domain2.org
   domainX.net
   etc
   etc

=cut

}

sub getDomainsCount {
    my $self = shift;

    undef $self->{'filter'};
    $self->{'filter'} = shift;

    $self->{'searchFilter'} = "&(objectclass=ispmanDomain)";
    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    return $self->getCount(
        $self->getConf('ldapBaseDN'),
        $self->{'searchFilter'},
        ["ispmanDomain"]
    );
}

sub domainHasService {
    my ( $self, $domain, $service ) = @_;
    my $dn = $self->getDomainDN($domain);
    return $self->getCount( $dn, "ispmanDomainService=$service",
        ['ispmanDomainService'], 'base' );

=item B<domainHashService>

   returns a 0 or 1  


I<EXAMPLE>


   #if you want to check that domain test.com has the service "mail"
   use ISPMan;
   my $ispman=ISPMan->new();
   if ($ispman->domainHasService("test.com", "mail")){
      print "Mail service exists for domain test.com\n";
   }

=cut

}

sub getDomainsWithService {
    my ( $self, $service ) = @_;
    my $domains = $self->getEntriesAsHashRef(
        $self->getConf('ldapBaseDN'),
        "&(objectclass=ispmanDomain)(ispmanDomainService=$service)",
        ["ispmanDomain"]
    );
    return $self->makeDomainHash($domains);

=item B<getDomainsWithService>

   returns a hashref of domains 
   that have the specified service


I<EXAMPLE>


   #if you want to list all domains that have domainservice=ftp
   use ISPMan;
   my $ispman=ISPMan->new();
   my $ftpDomains=$ispman->getDomainsWithService("ftp");
   for (keys %$ftpDomains) {
      print "$\n";
   }

   this will print something like
   domain1.com
   domain2.org
   domainX.net
   etc
   etc

=cut

}

sub getNodnsDomains {
    my $self = shift;
    return $self->makeDomainHash( $self->getDomains("ispmanDomainType=nodns") );

=item B<getNodnsDomains>

   returns a hashref of no dns domains

=cut

}

sub getPrimaryDomains {
    my $self = shift;
    return $self->makeDomainHash(
        $self->getDomains("ispmanDomainType=primary") );

=item B<getPrimaryDomains>

   returns a hashref of primary domains

=cut

}

sub getReplicaCountForDomain {
    my ( $self, $domain ) = @_;
    return $self->getCount(
        $self->getConf('ldapBaseDN'),
        "&(objectclass=ispmanDomain)(ispmanDomainType=replica)(ispmanReplicaMaster=$domain)",
        ["ispmanDomain"]
    );

=item B<getReplicaCountForDomain>

   returns a count of replicas for domain


I<EXAMPLE>

   #if you want to know how many  replicas for domain "4unet.net"
   use ISPMan;
   my $ispman=ISPMan->new();
   my $replicasCount=$ispman->getReplicaCountForDomain("4unet.net");
   print "You have $replicasCount replicas defined for domain 4unet.net";
   this will print something like
   you have 6 replicas defined for 4unet.net
   etc

=cut

}

sub getReplicaDomains {
    my $self = shift;
    return $self->makeDomainHash(
        $self->getDomains("ispmanDomainType=replica") );

=item B<getReplicaDomains>

   returns a hashref of replica domains

=cut

}

sub getReplicasOfDomain {
    my ( $self, $domain ) = @_;
    my $domains = $self->getEntriesAsHashRef(
        $self->getConf('ldapBaseDN'),
        "&(objectclass=ispmanDomain)(ispmanDomainType=replica)(ispmanReplicaMaster=$domain)",
        ["ispmanDomain"]
    );
    return $self->makeDomainHash($domains);

=item B<getReplicasOfDomain>

   returns a hashref of domains 
   that are a replica of another domain which is passed as the parameter


I<EXAMPLE>

   #if you want all replicas for domain "4unet.net"
   use ISPMan;
   my $ispman=ISPMan->new();
   my $replicas=$ispman->getReplicaOfDomain("4unet.net");
   for (keys %$replicas) {
      print "$\n";
   }
   this will print something like
   4u-net.net
   4unet.ch
   4unet.com
   4u-net.com
   etc
   etc

=cut

}

sub getSlaveDomains {
    my $self = shift;
    return $self->makeDomainHash( $self->getDomains("ispmanDomainType=slave") );

=item B<getSlaveDomains>

   returns a hashref of slave domains

=cut

}

sub getTransportMap {
    my $self   = shift;
    my $domain = shift;

    if ( $self->getDomainAttribute( $domain, 'ispmanDomainMailDeliveryMethod' )
        eq "smtp" )
    {
        my $mx = "";
        $mx = $self->getFirstMX($domain);
        $mx =~ s/\.$//g;
        return "smtp:$mx";
    }
    else {
        return "local:";
    }
}

sub gotoEditDomain {
    my $self = shift;
    my $r    = shift;
    $self->getDomainInfo( $r->param("ispmanDomain"), 1 );
    $self->editDomain($r);

=item B<gotoEditDomain>

Internal function, called from modify*Domain after the modification is done.
This function only exists so it can call getDomainInfo with a positive value
to flush the old information about the domain (because they were changed in
modify*Domain. Especially useful when running under mod_perl and for
ispman-agent)


=cut

}

sub isWebmailEnabled {
   my $self=shift;
   my $dn=shift;

   if ($self->branchExists($dn)) {
       return 1;
   } else {
       return 0;
   }
}

sub isDomainEditable {
    my $self   = shift;
    my $domain = shift;

    if ( $self->isDomainLocked($domain) ) {
        if (   $self->domainLockedBy($domain) eq $self->{'REMOTE_USER'}
            || $self->requiredAdminLevel(100) )
        {
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 1;
    }
}

sub isDomainLocked {
    my $self   = shift;
    my $domain = shift;

    return (
        $self->getDomainAttribute( $domain, "ispmanDomainLocked" ) eq "true" )
      ? 1
      : 0;

=item B<isDomainLocked>

   returns true or false.

=cut

}

sub lockDomain {
    my $self = shift;
    my ( $domain, $owner ) = @_;
    $self->setDomainAttribute( $domain, "ispmanDomainLocked",   "true" );
    $self->setDomainAttribute( $domain, "ispmanDomainLockedBy", "$owner" );

=item B<lockDomain>

   requires domain, name of the admin to lock the domain 


I<EXAMPLE>


   use ISPMan;
   my $ispman=ISPMan->new();
   $ispman->lockDomain("ispman.net", "aghaffar");


=cut

}

sub makeDomainDN {
    my $self = shift;
    my $text = shift;
    if ( $text !~ /^ispmanDomain=/ ) {
        $text = "ispmanDomain=$text, ";
        $text .= $self->getConf("ldapBaseDN");
    }
    return $text;

}

sub makeDomainHash {
    my $self    = shift;
    my $domains = shift;

    $self->{'tmpDomainHash'} = {};
    undef $self->{'tmpDomainHash'};

    for ( sort { $domains->{$a} cmp $domains->{$b} } keys %$domains ) {
        $self->{'tmpDomainHash'}{ $domains->{$_}{'ispmanDomain'} } = $_;
    }
    return $self->{'tmpDomainHash'};

=item B<makeDomainHash>

   Private method

   this routine is called by get*Domains, it takes a reference to the ldap result and
   returns it as a sorted hash of domain names and their LDAP dn.


=cut

}

sub modifyNoDNSDomain {
    my $self = shift;
    my $r    = shift;

    if ( $self->genericModifyDomain( $r, 'nodns' ) ) {
        $self->gotoEditDomain($r);
    }

=item B<modifyNoDNSDomain>

called from ispman.cgi, calls ISPMan::DomainMan::NoDNSDomain::modifyDomain
Modifies data for the nodns  Domain such as domain services, domain owner, etc


=cut

}

sub modifyPrimaryDomain {
    my $self = shift;
    my $r    = shift;

    if ( $self->genericModifyDomain( $r, 'primary' ) ) {
        $self->gotoEditDomain($r);
    }

=item B<modifyPrimaryDomain>

called from ispman.cgi, calls ISPMan::DomainMan::PrimaryDomain::modifyDomain
Modifies data for the Primary Domain such as domain services, domain owner, etc


=cut

}

sub modifyReplicaDomain {
    my $self = shift;
    my $r    = shift;
    if ( $self->genericModifyDomain( $r, 'replica' ) ) {
        $self->gotoEditDomain($r);
    }

=item B<modifyReplicaDomain>

called from ispman.cgi, calls ISPMan::DomainMan::ReplicaDomain::modifyDomain
Modifies ispmanReplicaMaster for the Replica domain


=cut

}

sub modifySlaveDomain {
    my $self = shift;
    my $r    = shift;
    if ( $self->genericModifyDomain( $r, 'slave' ) ) {
        $self->gotoEditDomain($r);
    }

=item B<modifySlaveDomain>

called from ispman.cgi, calls ISPMan::DomainMan::SlaveDomain::modifyDomain
Modifies data for the Slave Domain such as domain services, domain owner, etc


=cut

}

sub newDomain {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param("ispmanDomain");
    $domain =~ s/\s//g;    # remove all spaces
    $r->param( "ispmanDomain", $domain );

    if ( $self->domainExists($domain) ) {
        print "This domain already exists";
        exit;
    }
    my $domaintype = $r->param("ispmanDomainType");
    my $template =
      $self->getTemplate( "domains/add_" . $domaintype . "_Domain.tmpl" );
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<newDomain>

Loads and prints *Domain.tmpl
* could be Primary, Secondary, Replica or NoDNS

=cut

}

sub prepareDNSBranch {
    my $self = shift;
    return $self->prepareBranchForDN(
        join ",",
        (
            $self->getDomainAsDCObject(@_), "ou=DNS",
            $self->getConf("ldapBaseDN")
        )
    );
}

sub selectDomainType {
    my $self = shift;
    my $r    = shift;

    if (   $self->{'session'}
        && $self->{'session'}->param("logintype") eq "reseller"
        && !$self->getClients() )
    {
        print
          "No clients are defined for this reseller. Please add clients first!";
    }
    else {
        my $template = $self->getTemplate("domains/selectDomainType.tmpl");
        print $template->fill_in( PACKAGE => "ISPMan" );
    }

=item B<selectDomainType>

Loads and print selectDomainType.tmpl
This template is used when adding a new domain.
Gives you choice or domain.


=cut

}

sub setDomainAttribute {
    my $self      = shift;
    my $domain    = shift;
    my $attribute = shift;
    my $value     = shift;
    my $dn        = $self->makeDomainDN($domain);
    $self->modifyAttribute( $dn, $attribute, $value );

=item B<setDomainAttribute>

   requires domain name , attribute name, value.
   
   sets the value of the attribute for the  domain.
   
   

I<EXAMPLE>


   use ISPMan;
   my $ispman=ISPMan->new();
   
   $ispman->setDomainAttribute("ispman.org", "ispmanDomainOwner", "Atif Ghaffar");
   
   

=cut

}

sub setMailTransport {
    my $self      = shift;
    my $domain    = shift;
    my $transport = shift;
    $self->setDomainAttribute( $domain, "ispmanDomainMailDeliveryMethod",
        $transport );
    $self->addDomainSMTPProcess( $domain, "modifyTransport",
        "ispmanDomainMailDeliveryMethod=" . $self->getTransportMap($domain) );

    if ( $transport eq "smtp" ) {
        $self->addDomainSMTPProcess( $domain, "RemoveDestinationDomainEntry" );
        $self->addDomainSMTPProcess( $domain, "AddRelayDomainEntry" );
    }
    else {
        $self->addDomainSMTPProcess( $domain, "RemoveRelayDomainEntry" );
        $self->addDomainSMTPProcess( $domain, "AddDestinationDomainEntry" );
    }
}

sub summary {
    my $self     = shift;
    my $template = $self->getTemplate("domains/summary.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<summary>

Loads and prints the summary template

=cut

}

sub suspend_domain {
    my $self   = shift;
    my $domain = shift;
    my $dn     = $self->getDomainDN($domain);
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'disabled', 'ispmanStatus' => "suspended" } );
    return;
}

sub unlockDomain {
    my $self = shift;
    my ($domain) = @_;
    $self->setDomainAttribute( $domain, "ispmanDomainLocked",   "false" );
    $self->setDomainAttribute( $domain, "ispmanDomainLockedBy", "" );

=item B<unLockDomain>
   
   requires domain
   
   unlocks a previously locked domain

=cut

}

sub unsuspend_domain {
    my $self   = shift;
    my $domain = shift;
    my $dn     = $self->getDomainDN($domain);
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'enabled', 'ispmanStatus' => "active" } );
    return;
}

sub changeDomainPassword {
    my $self = shift;
    my ( $domain, $pass ) = @_;

    my $dn = $self->getDomainDN($domain);

    my $data = {};
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    return $self->updateEntryWithData( $dn, $data );
}

sub getDefaultFileHost {
    my $self = shift;

    my ($domain) = @_;

    my $_host;

    if ( $_host =
        $self->getDomainAttribute( $domain, "ispmanDomainDefaultFileServer" ) )
    {
        return $_host;
    }
    elsif ( $_host = $self->getHostGroupFirstMember('fileservergroup') ) {
        return $_host;
    }
    else {
        return 0;
    }
}

sub getDefaultMailHost {
    my $self = shift;

    my ($domain) = @_;

    my $_host;

    if ( $_host =
        $self->getDomainAttribute( $domain, "ispmanDomainDefaultMailDropHost" )
      )
    {
        return $_host;
    }
    elsif ( $_host = $self->getHostGroupFirstMember('mailstoregroup') ) {
        return $_host;
    }
    else {
        return 0;
    }
}

sub getDefaultWebHost {
    my $self = shift;
    my ($domain) = @_;

    my @hosts =
      $self->getDomainAttribute( $domain, "ispmanDomainDefaultWebHost" );

    unless (@hosts) {
        @hosts = $self->getHostGroupFirstMember('httpgroup');
    }

    return wantarray ? @hosts : \@hosts;
}

1;
__END__

