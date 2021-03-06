
=head1 NAME
ISPMan::DomainServices - Functions to Define and manage Domain Services.



=head1 SYNOPSIS

   In future there should be some functions to do with services and billing etc.
   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   
   I am slowly removing dependency on CGI.pm, so that for the CLI we don't have to do hacks.
   
   

=head1 DESCRIPTION


Some functions to read/write services 


=cut

package ISPMan::DomainServices;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  addDomainService
  addService2Domain
  addDomainService2Domain
  deleteDomainService
  manageDomainServices
  getDomainServices
  editDomainService
  getDomainServiceInfo

  getDomainServicesBranchDN
  getDomainServiceDN
);
$VERSION = '0.01';

sub getDomainServicesBranchDN {
    my $self = shift;

    # simply return the DN, generated by concatinating
    # ou=domainsServices with ldapBaseDN

# If one day, we want to change this to ou=serverConfig, ou=domainServices, .... etc
# it will require a change only at one place.

# Also note, we are not calling getConf('ldapBaseDN') but getting it from the Config hash
# i-e being nice to the LDAP server

    return join ",", ( "ou=domainServices", $self->{'Config'}{'ldapBaseDN'} );

}

sub getDomainServiceDN {
    my $self = shift;
    my ($service) = @_;

# Again, a util function to return the DN of the domain Service.
# End-programmers don't need to build this DN.
# This gives us the flexibility to change it in future without breaking the existing apps.

    # also reduces typo probability

    # functions like getDomainServiceDN are present in almost all modules
    # such  as
    # getDomainDN, getVhostDN, getUserDN etc

    return join ",", ( "ispmanDomainServiceName=$service",
        $self->getDomainServicesBranchDN() );

}

sub addDomainService {
    my $self = shift;

# object reference $self, separately shifted than the rest of the ARGS.
# this makes it nice for my IDE to show me all the parameters the function reqiure without the $self.

    my ( $service, $cn, $default, $description ) = @_;

    my $data;

#my $dn="ispmanDomainServiceName=$service, ou=domainServices, @{[$self->getConf('ldapBaseDN')]}";
    my $dn =
      $self->getDomainServiceDN($service)
      ;    # using the API function instead of generating the DN

    $data->{'objectclass'}                = "ispmanDomainService";
    $data->{'ispmanDomainServiceName'}    = $service;
    $data->{'ispmanDomainServiceAlias'}   = $cn || "undefined";
    $data->{'ispmanDomainServiceInfo'}    = $description || "undefined";
    $data->{'ispmanDomainServiceDefault'} = $default || "no";
    $self->addNewEntryWithData( $dn, $data );
}

sub addService2Domain {

    # changed to addDomainService2Domain
    # for consistency
    my $self = shift;
    my ( $service, $domain ) = @_;

    # please pass domain as the first argument.
    return $self->addDomainService2Domain( $domain, $service );
}

sub addDomainService2Domain {
    my $self = shift;

    my ( $domain, $service ) = @_;

    # please pass domain as the first argument.

    my $data;

    #my $dn="ispmanDomain=$domain, @{[$self->getConf('ldapBaseDN')]}";
    my $dn =
      $self->getDomainDN($domain)
      ;    #using API function instead of generating the DN
    $data->{'ispmanDomainService'} = $service;
    $self->addData2Entry( $dn, $data );
}

sub modifyDomainService {
    my $self = shift;
    my ( $service, $cn, $default, $description ) = @_;

    my $data;

#my $dn="ispmanDomainServiceName=$service, ou=domainServices, @{[$self->getConf('ldapBaseDN')]}";
    my $dn = $self->getDomainServiceDN($service);

    $data->{'cn'}          = $cn          || "undefined";
    $data->{'description'} = $description || "undefined";
    $data->{'default'}     = $default     || "no";
    $self->updateEntryWithData( $dn, $data );
}

sub deleteDomainService {
    my ( $self, $service ) = @_;

#my $dn="ispmanDomainServiceName=$service, ou=domainServices, @{[$self->getConf('ldapBaseDN')]}";
    my $dn = $self->getDomainServiceDN($service);

    $self->deleteEntry($dn);
}

sub getDomainServiceInfo {
    my $self        = shift;
    my ($service)   = @_;
    my $serviceInfo =
      $self->getEntryAsHashRef( $self->getDomainServiceDN($service) );
    return $serviceInfo;
}

sub getDomainServices {
    my $self = shift;
    return $self->getEntriesAsHashRef( $self->getDomainServicesBranchDN(),
        "objectclass=ispmanDomainService" );
}

sub editDomainService {
    my $self      = shift;
    my ($service) = @_;
    my $template  = $self->getTemplate("editDomainService.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub manageDomainServices {
    my $self = shift;
    return unless $ENV{'HTTP_USER_AGENT'};

    my $template = $self->getTemplate("manageDomainServices.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

1;
__END__

