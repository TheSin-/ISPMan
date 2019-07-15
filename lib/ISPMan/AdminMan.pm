package ISPMan::AdminMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  admins
  newAdmin
  _addAdmin
  addAdmin
  editAdmin
  updateAdmin
  deleteAdmin
  _deleteAdmin
  getAdmins
  createAdmin
  getAdminInfo
  getAdminsCount
  getAdminLevel
  requiredAdminLevel
);
$VERSION = '0.01';

sub admins {
    my $self = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    my $template = $self->getTemplate("admins/list.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub editAdmin {
    my $self = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    my $r = shift;
    $self->{'admin'} = $self->getAdminInfo( $r->param("uid") );
    my $template = $self->getTemplate("admins/edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub addAdmin {
    my $self = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    my $template = $self->getTemplate("admins/add.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub getAdminInfo {
    my $self = shift;
    my $uid  = shift;

    my $dn = "uid=$uid, ou=admins, ";
    $dn .= $self->getConf("ldapBaseDN");

    my $adminHash =
      $self->getEntryAsHashRef( $dn, "objectclass=ispmanSysadmin" );
    return $adminHash;
}

sub getAdminLevel {
    my $self      = shift;
    my $uid       = shift;
    my $adminInfo = $self->getAdminInfo($uid);
    return $adminInfo->{'ispmanSysadminLevel'};
}

sub getAdmins {
    my $self = shift;
    my $dn   = "ou=admins, ";
    $dn .= $self->getConf("ldapBaseDN");
    my $adminHash =
      $self->{'ldap'}->getEntriesAsHashRef( $dn, "objectclass=ispmanSysadmin" );
    return $adminHash;
}

sub updateAdmin {
    my $self = shift;
    return unless $self->requiredAdminLevel(100);
    my $r   = shift;
    my $uid = $r->param("uid");
    $uid =~ s/ //g;
    $r->param( "uid", $uid );

    my $dn = "uid=$uid, ou=admins, ";
    $dn .= $self->getConf("ldapBaseDN");
    $r->param( "dn", $dn );

    $r->param(
        "userPassword",
        $self->encryptPassWithMethod(
            $r->param("userPassword"),
            $self->getConf('userPassHashMethod')
        )
    );
    my $data;

    for (qw(uid cn ispmanSysadminMail userPassword ispmanSysadminLevel)) {
        $data->{$_} = $r->param($_) || "";
    }

    $self->updateEntryWithData( $dn, $data );
    $self->admins();

}

sub newAdmin {
    my $self = shift;
    return unless $self->requiredAdminLevel(100);

    my $r = shift;

    $self->_addAdmin(
        $r->param("uid"),
        $r->param("userPassword"),
        $r->param("ispmanSysadminLevel"),
        $r->param("cn"), $r->param("ispmanSysadminMail")
    );

    $self->admins();
}

sub _addAdmin {
    my $self = shift;
    my ( $uid, $pass, $level, $name, $mail ) = @_;
    my $data = {};

    $uid =~ s/ //g;

    $data->{'uid'}          = $uid;
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    $data->{'ispmanSysadminLevel'} = $level;
    $data->{'ispmanSysadminMail'}  = $mail;
    $data->{'cn'}                  = $name;
    $data->{'objectClass'}         = "ispmanSysadmin";
    $data->{'ou'}                  = "admins";

    my $dn = join ',',
      ( "uid=$uid", "ou=admins", $self->{'Config'}{'ldapBaseDN'} );
    $self->addNewEntryWithData( $dn, $data );
}

sub deleteAdmin {
    my $self = shift;
    return unless $self->requiredAdminLevel(100);
    my $r = shift;
    $self->_deleteAdmin( $r->param("uid") );
    $self->admins();

}

sub _deleteAdmin {
    my $self = shift;
    my ($uid) = @_;

    my $dn = join ',',
      ( "uid=$uid", "ou=admins", $self->{'Config'}{'ldapBaseDN'} );
    $self->deleteEntry($dn);
}

sub requiredAdminLevel {
    my $self     = shift;
    my $minlevel = shift;

    if ( $self->{'session'} ) {

        # First Check.
        # Is this user Admin
        unless ( $self->{'session'}->param("logintype") eq "admin" ) {

            # return error
            print "Sorry. You are not logged in as admin";
            return 0;
        }
    }

    my $uid = $self->{'session'}->param("uid");

    if ( $self->{'Config'}->{'debug'} == 3 ) {
        print "UID: $uid<br>";
    }
    my $level = $self->getAdminLevel($uid);
    if ( $self->{'Config'}->{'debug'} == 3 ) {
        print "AdminLevel: $level";
    }

    if ( $level < $minlevel ) {
        print
"Sorry this action is only allowed by admins with a minimum level of $minlevel<br>You have only $level";
        return 0;
    }
    else {
        return 1;
    }
}

1;

__END__

