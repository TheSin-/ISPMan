package ISPMan::ApacheMan::Aliases;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getAliasesBranchDN
  getAliasDN
  getAliases

  addAlias
  add_alias

  updateAlias
  update_alias

  deleteAlias
  delete_alias
);
$VERSION = '0.01';

sub getAliasesBranchDN {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $vhostDN = $self->getVhostDN( $domain, $vhost );
    return join ",", ( "ou=vhostAliases", $vhostDN );
}

sub getAliasDN {
    my $self = shift;
    my ( $domain, $vhost, $alias ) = @_;

    my $dn = join ",",
      (
        "ispmanVhostServerAlias=$alias",
        $self->getAliasesBranchDN( $domain, $vhost )
      );
    return $dn;

}

sub getAliases {
    my $self = shift;
    my ( $domain, $vhost ) = @_;
    my $branch = $self->getAliasesBranchDN( $domain, $vhost );
    return $self->getEntriesAsHashRef(
        $branch,
        "objectclass=ispmanVirtualHostAlias",
        ['ispmanVhostServerAlias']
    );

}

sub addAlias {
    my $self = shift;
    my $r    = shift;

    $self->add_alias(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        $r->param("ispmanVhostServerAlias")
    );

    $r->param( "section", "aliases" );
    $self->editVhost($r);
}

sub add_alias {
    my $self = shift;
    my ( $domain, $vhost, $alias ) = @_;

    my $dn = $self->getAliasDN( $domain, $vhost, $alias );
    my $branch = $self->getAliasesBranchDN( $domain, $vhost );
    $self->prepareBranchForDN($branch);

    $self->addNewEntryWithData(
        $dn,
        {
            'ispmanVhostServerAlias' => $alias,
            'ispmanDomain'           => $domain,
            'ispmanVhostName'        => $vhost,
            'objectclass'            => 'ispmanVirtualHostAlias'

        }
    );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
    
    # if alias points to foreign domain skip DNS entry
    return if $alias =~ /\..+/;  
    
    if ( $self->checkDomainType( $domain, "primary" ) ) {
        $self->newDNSRecord( $domain, "cNAMERecord", $alias, $vhost,
            { txTRecord => "ispmanVirtualHostAlias:$vhost.$domain" } );
    }

}

sub updateAlias {
    my $self = shift;
    my $r    = shift;

    $self->update_alias(
        $r->param("ispmanDomain"),           $r->param("ispmanVhostName"),
        $r->param("ispmanVhostServerAlias"), $r->param("modifyAlias")
    );

    $r->param( "section", "aliases" );
    $self->editVhost($r);
}

sub update_alias {

    # update Alias is
    # delete Old Entry
    # create new entry

    my $self = shift;
    my ( $domain, $vhost, $alias, $oldalias ) = @_;
    if ( $oldalias && $oldalias ne $alias ) {
        $self->delete_alias( $domain, $vhost, $oldalias );
        return $self->add_alias( $domain, $vhost, $alias );
    }

    my $dn = $self->getAliasDN( $domain, $vhost, $alias );

    $self->updateEntryWithData( $dn,, { 'ispmanVhostServerAlias' => $alias } );
    $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
}

sub deleteAlias {
    my $self = shift;
    my $r    = shift;
    $self->delete_alias(
        $r->param("ispmanDomain"),
        $r->param("ispmanVhostName"),
        $r->param("ispmanVhostServerAlias")
    );
    $r->param( "section", "aliases" );
    $self->editVhost($r);
}

sub delete_alias {
    my $self = shift;
    my ( $domain, $vhost, $alias ) = @_;
    my $dn = $self->getAliasDN( $domain, $vhost, $alias );
    if ( $self->deleteEntry($dn) ) {
        $self->addVhostProcess( $domain, $vhost, "ModifyVirtualHost", "ispmanVhostName=$vhost" );
    }
    $self->deleteDNSRecord( $domain, "cNAMERecord", $alias, $vhost,
        { txTRecord => "ispmanVirtualHostAlias:$vhost.$domain" } );

#my $vhostCnames=$self->getCNAMERecordsForHost($domain, $vhost, "txTRecord=ispmanVirtualHostAlias:$vhost.$domain");

}

1;

__END__

