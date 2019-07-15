package ISPMan::ApacheMan::Redirects;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getRedirectionsBranchDN
  getRedirectionDN
  getRedirections

  addRedirect
  add_redirect

  updateRedirect
  update_redirect

  deleteRedirect
  delete_redirect
);
$VERSION = '0.01';

sub getRedirectionsBranchDN {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $vhostDN = $self->getVhostDN( $domain, $vhost );
    return join ",", ( "ou=urlRedirections", $vhostDN );
}

sub getRedirectionDN {
    my $self = shift;
    my ( $domain, $vhost, $url ) = @_;

    my $dn = join ",",
      (
        "ispmanVhostRedirectURL=$url",
        $self->getRedirectionsBranchDN( $domain, $vhost )
      );
    return $dn;

}

sub getRedirections {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $branch = $self->getRedirectionsBranchDN( $domain, $vhost );
    return $self->getEntriesAsHashRef(
        $branch,
        "objectclass=ispmanVirtualHostRedirection",
        [ 'ispmanVhostRedirectURL', 'ispmanVhostRedirectLocation' ]
    );

}

sub addRedirect {
    my $self = shift;
    my $r    = shift;

    my $branch = $self->getRedirectionsBranchDN( $r->param("ispmanDomain"),
        $r->param("ispmanVhostName") );
    $self->prepareBranchForDN($branch);

    $self->add_redirect(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        $r->param("ispmanVhostRedirectURL"),
        $r->param("ispmanVhostRedirectLocation")
    );

    $r->param( "section", "redirects" );
    $self->editVhost($r);
}

sub add_redirect {
    my $self = shift;
    my ( $domain, $vhost, $source, $target ) = @_;

    my $dn = $self->getRedirectionDN( $domain, $vhost, $source );

    $self->addNewEntryWithData(
        $dn,
        {
            'ispmanVhostRedirectURL'      => $source,
            'ispmanVhostRedirectLocation' => $target,
            'ispmanDomain'                => $domain,
            'ispmanVhostName'             => $vhost,
            'objectclass'                 => 'ispmanVirtualHostRedirection'

        }
    );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
}

sub updateRedirect {

    my $self = shift;
    my $r    = shift;
    $self->update_redirect(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        $r->param("ispmanVhostRedirectURL"),
        $r->param("ispmanVhostRedirectLocation"),
        $r->param("modifyURL")
    );

    $r->param( "section", "redirects" );
    $self->editVhost($r);
}

sub update_redirect {

    # update redirection is
    # delete Old Entry
    # create new entry
    my $self = shift;
    my ( $domain, $vhost, $ispmanVhostRedirectURL, $ispmanVhostRedirectLocation,
        $oldURL )
      = @_;

    if ( $oldURL && $oldURL ne $ispmanVhostRedirectURL ) {
        $self->delete_redirect( $domain, $vhost, $oldURL );
        return $self->add_redirect( $domain, $vhost, $ispmanVhostRedirectURL,
            $ispmanVhostRedirectLocation );
    }

    my $dn =
      $self->getRedirectionDN( $domain, $vhost, $ispmanVhostRedirectURL );

    $self->updateEntryWithData(
        $dn,
        ,
        {
            'ispmanVhostRedirectURL'      => $ispmanVhostRedirectURL,
            'ispmanVhostRedirectLocation' => $ispmanVhostRedirectLocation
        }
    );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
}

sub deleteRedirect {
    my $self = shift;
    my $r    = shift;
    $self->delete_redirect(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        $r->param("ispmanVhostRedirectURL")
    );
    $r->param( "section", "redirects" );
    $self->editVhost($r);
}

sub delete_redirect {
    my $self = shift;
    my ( $domain, $vhost, $url ) = @_;
    my $dn = $self->getRedirectionDN( $domain, $vhost, $url );
    if ( $self->deleteEntry($dn) ) {
        $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
    }

}

1;

__END__

