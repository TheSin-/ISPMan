package ISPMan::HostGroupMan;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  addHostGroupForm
  manageHostGroups
  makeHostGroupsBranch
  makeHostGroupDN
  getHostGroups
  editHostGroup
  deleteHostGroup
  getHostGroupInfo
  getHostGroupMembers
  getHostGroupFirstMember
  getGroupMembers
  add_host_group
  modify_host_group
  addHost2HostGroup
);
$VERSION = '0.01';

sub addHostGroupForm {
    my $self = shift;
    return unless $ENV{'HTTP_USER_AGENT'};
    my $template = $self->getTemplate("hostgroups/addHostGroup.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub manageHostGroups {
    my $self = shift;
    return unless $ENV{'HTTP_USER_AGENT'};
    my $template = $self->getTemplate("hostgroups/manageHostGroups.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub makeHostGroupsBranch {

    # return the branch for hostgroup.
    # no need to retype the thing everytime and have more chances of typo errors
    my $self = shift;
    return join ",", ( "ou=hostgroups", $self->{'Config'}{'ldapBaseDN'} );
}

sub makeHostGroupDN {
    my $self = shift;
    my ($ispmanHostGroupName) = @_;
    return join ",",
      (
        "ispmanHostGroupName=$ispmanHostGroupName",
        $self->makeHostGroupsBranch()
      );
}

sub add_host_group {
    my $self = shift;
    if ( $self->{'session'} ) {
        return unless ( $self->{'session'}->param("logintype") eq "admin" );
        return unless $self->requiredAdminLevel(100);
    }
    my ( $ispmanHostGroupName, $ispmanHostGroupInfo ) = @_;
    my $data;
    $data->{'ispmanHostGroupName'} = $ispmanHostGroupName;
    $data->{'ispmanHostGroupInfo'} = $ispmanHostGroupInfo || "undefined";
    $data->{'objectclass'}         = "ispmanHostGroup";
    my $dn = $self->makeHostGroupDN($ispmanHostGroupName);
    $self->addNewEntryWithData( $dn, $data );
}

sub modify_host_group {
    my $self = shift;
    if ( $self->{'session'} ) {
        return unless ( $self->{'session'}->param("logintype") eq "admin" );
        return unless $self->requiredAdminLevel(100);
    }
    my ( $ispmanHostGroupName, $ispmanHostGroupInfo, $ispmanHostGroupMember ) =
      @_;
    my $data;
    my $dn = $self->makeHostGroupDN($ispmanHostGroupName);

    $data->{'ispmanHostGroupInfo'}   = $ispmanHostGroupInfo   || "undefined";
    $data->{'ispmanHostGroupMember'} = $ispmanHostGroupMember || "";
    $self->updateEntryWithData( $dn, $data );

}

sub addHost2HostGroup {
    my $self = shift;
    my ( $ispmanHostGroupName, $ispmanHostName ) = @_;
    my $data;
    my $dn = $self->makeHostGroupDN($ispmanHostGroupName);

    #should check here if the $ispmanHostName is defined as a host

    $data->{'ispmanHostGroupMember'} = $ispmanHostName;
    $self->addData2Entry( $dn, $data );
}

sub deleteHostGroup {
    my $self = shift;
    if ( $self->{'session'} ) {
        return unless ( $self->{'session'}->param("logintype") eq "admin" );
        return unless $self->requiredAdminLevel(100);
    }

    my ($ispmanHostGroupName) = @_;
    my $hostGroupInfo = $self->getHostGroupInfo($ispmanHostGroupName);
    my @members = $self->as_array( $hostGroupInfo->{'ispmanHostGroupMember'} );

    if ( $hostGroupInfo->{'ispmanHostGroupMember'} ) {
        print
"Sorry cannot delete this group. This group has the following members\n";
        print join ", \n", @members;
    }
    else {
        my $dn = $self->makeHostGroupDN($ispmanHostGroupName);
        $self->deleteEntry($dn);
    }

}

sub getHostGroupInfo {
    my $self = shift;
    my ($ispmanHostGroupName) = @_;
    return $self->getEntryAsHashRef(
        $self->makeHostGroupDN($ispmanHostGroupName) );
}

sub getHostGroups {
    my $self = shift;
    return $self->getEntriesAsHashRef( $self->makeHostGroupsBranch(),
        "objectclass=ispmanHostGroup" );
}

sub editHostGroup {
    my $self     = shift;
    my $template = $self->getTemplate("hostgroups/editHostGroup.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub getHostGroupMembers {
    my $self                  = shift;
    my ($ispmanHostGroupName) = @_;
    my $hostGroupInfo         = $self->getHostGroupInfo($ispmanHostGroupName);
    return
      wantarray
      ? $self->as_array( $hostGroupInfo->{'ispmanHostGroupMember'} )
      : $self->as_arrayref( $hostGroupInfo->{'ispmanHostGroupMember'} );
}

sub getHostGroupFirstMember {

    # Return the first member from the list
    # This can be used as default where no other
    # Value is specified
    my $self             = shift;
    my $hostGroupMembers = $self->getHostGroupMembers(@_);
    return $hostGroupMembers->[0];

}

sub getGroupMembers {

    #this function renamed to getHostGroupMember.
    #it should be removed when all references to this function are removed.

    my $self = shift;
    return $self->getHostGroupMembers(@_);

}

1;
__END__
   
