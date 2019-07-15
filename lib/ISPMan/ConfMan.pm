
=head1 NAME
ISPMan::ConfMan - This package manages configurable items kept in the LDAP directory




=head1 SYNOPSIS

   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


This module is responsible for loading/editing confvars from LDAP

=head1 METHODS


=over 4

=cut

package ISPMan::ConfMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  configure
  selectModule
  getConfModules
  editModule
  modifyModule
  getConfVars
  setConfVar
  getConfVarDN
  getConfModuleDN
);

$VERSION = '0.01';

sub configure {
    my $self = shift;
    my $r    = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    my $template = $self->getTemplate("modules/selectConfModule.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub getConfModuleDN {
    my $self = shift;
    my ($module) = shift;
    return "ispmanModule=$module,ou=conf, @{[$self->getConf('ldapBaseDN')]}";
}

sub getConfVarDN {
    my $self = shift;
    my ( $module, $var ) = @_;
    return join ',', "ispmanVar=$var", $self->getConfModuleDN($module);
}

sub getConfModules {
    my $self = shift;
    $self->log_event("running getConfModules");
    return $self->{'ldap'}->getEntriesAsHashRef(
        "ou=conf, @{[$self->getConf('ldapBaseDN')]}",
        "objectclass=ispmanconfmodule",
        [ "ispmanModule", "description", "ispmanModuleAlias" ],
        'one'
    );
}

sub getConfVars {
    my $self   = shift;
    my $module = shift;
    $module ||= "*";
    return $self->{'ldap'}->getEntriesAsHashRef(
        "ou=conf, @{[$self->getConf('ldapBaseDN')]}",
        "&(objectclass=ispmanConfVar)(ispmanModule=$module)",
        [ "ispmanModule", "ispmanVar", "ispmanVarAlias", "ispmanVal", "ispmanQuestion" ]
    );
}

sub editModule {
    my $self = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    my $r      = shift;
    my $module = $r->param("module");
    $self->{'moduleinfo'} =
      $self->{'ldap'}->getEntriesAsHashRef( $self->getConfModuleDN($module),
        "objectclass=ispmanConfVar" );
    my $template = $self->getTemplate("modules/editModule.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub setConfVar {
    my $self = shift;
    my ( $module, $var, $val ) = @_;
    my $dn =
"ispmanVar=$var, ispmanModule=$module, ou=conf, @{[$self->getConf('ldapBaseDN')]}";
    $self->updateEntryWithData( $dn, { 'ispmanVal' => $val } );
}

sub modifyModule {
    my $self = shift;
    my $r    = shift;
    return unless $self->{'session'}->param("logintype") eq "admin";
    return unless $self->requiredAdminLevel(100);

    $r->delete("mode");
    my $module = $r->param("module");
    $r->delete("module");
    my ( $dn, $data );

    for ( $r->param ) {
        my $dn =
"ispmanVar=$_, ispmanModule=$module, ou=conf, @{[$self->getConf('ldapBaseDN')]}";
        $data->{'ispmanVal'} = $r->param($_);
        $self->updateEntryWithData( $dn, $data );
    }
    if ( $self->getConf("debug") > 2 ) {
        print "Saved $module with <br>";
        print $r->as_string ;
    }
    print '<p><a href="'
      . $ENV{"SCRIPT_NAME"}
      . '?mode=configure">Return to Configuration Menu</a></p>';
}

1;

__END__

