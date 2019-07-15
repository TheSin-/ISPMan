package ISPMan::ApacheMan::Acls;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getAclsBranchDN
  getAclDN
  AclExists
  getAcls
  addAcl
  add_acl
  addVhostAcl
  updateAcl
  update_acl
  updateVhostAcl
  deleteAcl
  deleteVhostAcl
  delete_acl

);
$VERSION = '0.01';

sub getAclsBranchDN {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $vhostDN = $self->getVhostDN( $domain, $vhost );
    return join ",", ( "ou=httpAcls", $vhostDN );
}

sub getAclDN {
    my $self = shift;
    my ( $domain, $vhost, $url ) = @_;

    my $dn = join ",",
      (
        "ispmanVhostAclLocation=$url", $self->getAclsBranchDN( $domain, $vhost )
      );
    return $dn;
}

sub AclExists {
    my $self = shift;
    my ( $domain, $vhost, $url ) = @_;
    my $dn = $self->getAclDN( $domain, $vhost, $url );
    return $self->entryExists($dn);
}

sub getAcls {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $branch = $self->getAclsBranchDN( $domain, $vhost );
    return $self->getEntriesAsHashRef(
        $branch,
        "objectclass=ispmanVirtualHostAcl",
        [ 'ispmanVhostAclLocation', 'ispmanVhostAclAllowUser' ]
    );

}

sub addACL {
    goto("add_acl");
}

sub addVhostAcl {
    my $self = shift;
    my $r    = shift;
    if ( $self->AclExists( $r->param('newIspmanVhostAclLocation') ) ) {
        $r->param( "errors", "An ACL for this location already exists." );
    }
    else {
        $r->param( "ispmanVhostAclLocation",
            $r->param("newIspmanVhostAclLocation") );
        $r->param( "ispmanVhostAclAllowUser",
            $r->param("newIspmanVhostAclAllowUser") );
        $self->add_acl($r);
    }
    $r->param( "mode",    "editVhost" );
    $r->param( "section", "acls" );
    $self->editVhost($r);

}

sub add_acl {
    my $self   = shift;
    my $r      = shift;
    my $branch = $self->getAclsBranchDN( $r->param("ispmanDomain"),
        $r->param("ispmanVhostName") );
    $self->prepareBranchForDN($branch);

    $self->addDataFromLdif( "templates/acl.vhost.ldif.template", $r );
    $self->addVhostProcess(
        $r->param("ispmanDomain"), $r->param("ispmanVhostName"),
        "ModifyVirtualHost",       "ispmanVhostName=". $r->param("ispmanVhostName")
    );
}

sub updateAcl
{ #used by CCP. Should be obseleted and instead delete_acl should be used with domain, vhost and url as params
    my $self = shift;
    my $r    = shift;

    $self->updateEntryWithData(
        $r->param('dn'),
        {
            'ispmanVhostAclLocation'  => $r->param('ispmanVhostAclLocation'),
            'ispmanVhostAclAllowUser' =>
              $self->as_arrayref( $r->param('ispmanVhostAclAllowUser') )
        }
    );
    $self->addVhostProcess(
        $r->param("ispmanDomain"), $r->param("ispmanVhostName"),
        "ModifyVirtualHost",       "ispmanVhostName=". $r->param("ispmanVhostName")
    );
}

sub updateVhostAcl {    # used by the admin panel
    my $self = shift;
    my $r    = shift;
    $self->update_acl(
        $r->param('ispmanDomain'),
        $r->param('ispmanVhostName'),
        $r->param('ispmanVhostAclLocation'),
        $r->param('ispmanVhostAclAllowUser')
    );
    $r->delete("ispmanVhostAclLocation");
    $r->param( "mode",    "editVhost" );
    $r->param( "section", "acls" );
    $self->editVhost($r);
}

sub update_acl {
    my $self = shift;
    my ( $domain, $vhost, $url, @users ) = @_;
    my $aclDN = $self->getAclDN( $domain, $vhost, $url );
    $self->updateEntryWithData(
        $aclDN,
        {
            'ispmanVhostAclLocation'  => $url,
            'ispmanVhostAclAllowUser' => $self->as_arrayref(@users)
        }
    );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
}

sub deleteVhostAcl {
    my $self = shift;
    my $r    = shift;
    $self->delete_acl(
        $r->param('ispmanDomain'),
        $r->param('ispmanVhostName'),
        $r->param('ispmanVhostAclLocation')
    );
    $r->delete("ispmanVhostAclLocation");
    $r->param( "mode",    "editVhost" );
    $r->param( "section", "acls" );
    $self->editVhost($r);
}

sub deleteAcl
{ #used by CCP. Should be obseleted and instead delete_acl should be used with domain, vhost and url as params
    my $self = shift;
    my $r    = shift;
    print "Deleting ", $r->param('dn');

    if ( $self->deleteEntry( $r->param('dn') ) ) {
        $self->addVhostProcess(
            $r->param("ispmanDomain"), $r->param("ispmanVhostName"),
            "ModifyVirtualHost",       "ispmanVhostName="  . $r->param("ispmanVhostName")
        );
    }

}

sub delete_acl {
    my $self = shift;
    my ( $domain, $vhost, $url ) = @_;
    my $aclDN = $self->getAclDN( $domain, $vhost, $url );
    if ( $self->deleteEntry($aclDN) ) {
        $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=" . $vhost );
    }
}

1;

__END__

