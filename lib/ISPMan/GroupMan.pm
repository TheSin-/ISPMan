package ISPMan::GroupMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  createGroup
  cantAddGroupsToReplicaDomain
  newGroup
  addGroup
  getGroups
  groupExists
  killGroup
  deleteGroup
  editGroup
  updateGroup
  getGroupInfo
);

$VERSION = '0.01';

use ISPMan::Config;
$Config = ISPMan::Config->new();

sub cantAddGroupsToReplicaDomain {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param("ispmanDomain");
    print
"Sorry cannot add groups to a replica domain<br>Instead add groups to its master domain which is ";
    my $replicaMaster =
      $self->{'ldap'}
      ->getEntry( "ispmanDomain=$domain, $Config->{'ldapBaseDN'}",
        , ["ispmanReplicaMaster"] )->get_value("ispmanReplicaMaster");
    print "<h1>$replicaMaster</h1>";
}

sub createGroup {
    my $self       = shift;
    my $r          = shift;
    my $dn         = $r->param("dn");
    my $domaintype = $self->getDomainType( $r->param("ispmanDomain") );
    return $self->cantAddGroupsToReplicaDomain($r)
      if lc($domaintype) eq "replica";

    my $template = $self->getTemplate("addgroup.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub newGroup {
    my $self = shift;
    my $r    = shift;
    if ( $self->addGroup($r) ) {
        print $self->refreshSignal( $r->param("ispmanDomain") );
        $self->editGroup($r);
    }
}

sub addGroup {
    my $self = shift;
    my $r    = shift;

    my $groupname = $r->param("groupname");
    $groupname = lc($groupname);
    $groupname =~ s/[^a-z]//g;
    $r->param( "name", $groupname );

    my $description = $r->param("description");
    my $domain      = $r->param("ispmanDomain");

    my $_name = join '_', ( $r->param("groupname"), $r->param("ispmanDomain") );
    $_name =~ s/\./_/g;

    $r->param( "cn", $_name );

    my $dn =
      "gid=$_name, ou=groups, ispmanDomain=$domain, "
      . $self->{'Config'}{'ldapBaseDN'};

    $r->param( "dn", $dn );

    if ( $self->{'ldap'}->AddGroup($r) ) {
        return 1;
    }
}

sub killGroup {
    my $self = shift;
    my $dn   = shift;

    #bare function to remove user,
    #can be called from CLI or other subroutines
    # get all values from the dn to the hash

    $self->{'group'} = $self->{'ldap'}->getEntryAsHashRef($dn);

    if ( $self->{'ldap'}->DeleteUser($dn) ) {
    }
}

sub getGroups {
    my $self      = shift;
    my $dn        = shift;
    my $grouphash =
      $self->{'ldap'}
      ->getEntriesAsHashRef( $dn, "objectclass=group", [ "name", "cn" ] );
    my $group;

    for ( keys %$grouphash ) {
        $group->{ $grouphash->{$_}{'name'} } = $_;
    }
    return $group;
}

sub editGroup {
    my $self = shift;
    my $r    = shift;
    my $userhash;
    my $dn = $r->param("dn");

    $self->{'group'} = $self->{'ldap'}->getEntryAsHashRef( $r->param("dn") );

    $userhash = $self->{'ldap'}->getEntriesAsHashRef( $Config->{'ldapBaseDN'},
        "objectclass=person",
        [ "cn", "uid", "mailacceptinggeneralid", "domain" ] );

    for ( keys %$userhash ) {
        $self->{'users'}->{ $userhash->{$_}->{'uid'} } = $userhash->{$_};
    }

    my $template = $self->getTemplate("editgroup.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub getGroupInfo {
    my $self = shift;
    my $gid  = shift;
    my $_hr  =
      $self->{'ldap'}
      ->getEntriesAsHashRef( $Config->{'ldapBaseDN'}, "uid=$gid" );
    my ($key) = keys %{$_hr};
    $self->{'groupinfo'}{$gid} = $_hr->{$key};
    return $self->{'group'}{$gid};
}

sub deleteGroup {
    my $self = shift;
    my $r    = shift;

    my $gid    = $r->param("gid");
    my $domain = $r->param("ispmanDomain");
    $self->killGroup( $r->param("dn") );
    print $self->refreshSignal( $r->param("ispmanDomain") );
}

sub updateGroup {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    $r->param("description");

    $self->{'ldap'}->updateEntry($r);
    print $self->refreshSignal( $r->param("ispmanDomain") );
}

sub groupExists {
    my $self = shift;
    my $gid  = shift;
    return $self->getCount($gid);
}

__END__

