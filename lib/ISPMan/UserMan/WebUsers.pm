package ISPMan::UserMan::WebUsers;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getWebusersBranchDN
  getWebuserDN
  getWebusers
  getWebuserInfo

  editWebUser
  updateWebUser
  addWebUser
  deleteWebUser

  add_webuser

  update_webuser

  delete_webuser
);
$VERSION = '0.01';

sub editWebUser {
    my $self = shift;
    my $r    = shift;
    $self->{'webuser'} = $self->getWebuserInfo( $r->param("ispmanDomain"),
        $r->param("ispmanUserId") );
    my $template = $self->getTemplate("webusers/edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub updateWebUser {
    my $self = shift;
    my $r    = shift;
    $self->update_webuser(
        $r->param("ispmanDomain"),
        $r->param("ispmanUserId"),
        $r->param("userPassword")
    );
    $self->editWebUser($r);
}

sub deleteWebUser {
    my $self = shift;
    my $r    = shift;
    $self->delete_webuser( $r->param("ispmanDomain"),
        $r->param("ispmanUserId") );
    print "Webuser ", $r->param("ispmanUserId"), " for domain ",
      $r->param("ispmanDomain"), " deleted<br>";
    print $self->refreshSignal( $r->param("ispmanDomain") );
}

sub addWebUser {
    my $self = shift;
    my $r    = shift;
    $self->add_webuser(
        $r->param("ispmanDomain"),
        $r->param("ispmanUserId"),
        $r->param("userPassword")
    );
    print $self->refreshSignal( $r->param("ispmanDomain") );
    $self->editWebUser($r);
}

sub getWebusersBranchDN {
    my $self = shift;
    my ($domain) = @_;
    return join ",", ( "ou=httpusers", $self->getDomainDN($domain) );
}

sub getWebuserDN {
    my $self = shift;
    my ( $domain, $user ) = @_;

    my $dn = join ",",
      ( "ispmanUserId=$user", $self->getWebusersBranchDN($domain) );
    return $dn;
}

sub getWebusers {
    my $self     = shift;
    my ($domain) = @_;
    my $branch   = $self->getWebusersBranchDN($domain);
    return $self->getEntriesAsHashRef(
        $branch,
        "objectclass=ispmanVirtualHostUser",
        [ 'ispmanUserId', 'userPassword' ]
    );
}

sub getWebuserInfo {
    my $self = shift;
    my ( $domain, $user ) = @_;
    my $dn = $self->getWebuserDN( $domain, $user );
    return $self->getEntryAsHashRef($dn);
}

sub add_webuser {
    my $self = shift;
    my ( $domain, $user, $pass ) = @_;
    return if $self->userExists( $self->create_uid( $user, $domain ) );

    my $branch = $self->getWebusersBranchDN($domain);
    $self->prepareBranchForDN($branch);

    my $dn = $self->getWebuserDN( $domain, $user );

    my $data = {
        "ispmanUserId" => $user,
        "ispmanDomain" => $domain,
        "objectclass"  => "ispmanVirtualHostUser"
    };

    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    $self->addNewEntryWithData( $dn, $data );
}

sub update_webuser {

    # update webuser is
    # delete Old Entry
    # create new entry
    my $self = shift;
    my ( $domain, $user, $pass, $olduser ) = @_;

    if ( $olduser && $olduser ne $user ) {
        $self->delete_webuser( $domain, $olduser );
        return $self->add_webuser( $domain, $user, $pass );
    }

    my $dn = $self->getWebuserDN( $domain, $user );
    my $data = {};
    $data->{"ispmanUserId"} = $user;
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );

    $self->updateEntryWithData( $dn, $data );
}

sub delete_webuser {
    my $self = shift;
    my ( $domain, $user ) = @_;
    my $dn = $self->getWebuserDN( $domain, $user );
    if ( $self->deleteEntry($dn) ) {
        return 1;
    }
}

1;

__END__

