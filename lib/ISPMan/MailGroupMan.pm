
=head1 NAME
ISPMan::MailGroupMail - Functions to manage rfc822MailGroups



=head1 SYNOPSIS

   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


Some functions to read/write hosts and their group memberships


=cut

package ISPMan::MailGroupMan;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getMailGroupsBranchDN
  getMailGroupDN

  get_mail_groups
  get_mail_group_info

  update_mail_group
  delete_mail_group

  addMailGroup
  newMailGroup
  createMailGroup
  getMailGroups
  editMailGroup
  updateMailGroup
  deleteMailGroup
  removeMailGroup

);
$VERSION = '0.01';

sub getMailGroupsBranchDN {
    my $self = shift;
    my ($domain) = @_;
    return join ',', ( "ou=ispmanMailGroup", $self->getDomainDN($domain) );

}

sub getMailGroupDN {
    my $self = shift;
    my ( $domain, $group ) = @_;
    return join ',', ( "cn=$group", $self->getMailGroupsBranchDN($domain) );
}

sub addMailGroup {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param("ispmanDomain");
    $self->prepareBranchForDN(
        $self->getMailGroupsBranchDN( $r->param("ispmanDomain") ) );
    $self->addDataFromLdif( "templates/domain.rfc822MailGroup.ldif.template",
        $r );
}

sub createMailGroup {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    my $domaintype = $self->getDomainType( $r->param("ispmanDomain") );

    return $self->cantAddUsersToReplicaDomain($r)
      if lc($domaintype) eq "replica";
    my $template;
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("mailgroups/add.tmpl");
    }
    else {
        $template = $self->getTemplate("ro.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub newMailGroup {
    my $self = shift;
    my $r    = shift;
    if ( $self->addMailGroup($r) ) {
        print "Mailgroup Added";
        print $self->refreshSignal( $r->param("ispmanDomain") );
    }
}

sub editMailGroup {
    my $self = shift;
    my $r    = shift;
    $self->{'mailgroup'} = $self->get_mail_group_info($r->param("ispmanDomain"),$r->param("mailGroup"));
    my $template;
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("mailgroups/edit.tmpl");
    }
    else {
        $template = $self->getTemplate("mailgroups/view.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub getMailGroups {
    my $self           = shift;
    my $dn             = shift;
    my $mailgroupshash =
      $self->getEntriesAsHashRef( $dn, "objectclass=ispmanMailGroup",
        [ "cn", "mailLocalAddress", "mailForwardingAddress" ] );
    return $mailgroupshash;
}

sub get_mail_groups {
    my $self     = shift;
    my ($domain) = @_;
    my $dn       = $self->getMailGroupsBranchDN($domain);
    return $self->getEntriesAsHashRef( $dn, "objectclass=ispmanMailGroup",
        [ "cn", "mailLocalAddress", "mailForwardingAddress", "mailAlias" ] );
}

sub get_mail_group_info {
    my $self = shift;
    my ( $domain, $group ) = @_;
    my $dn = $self->getMailGroupDN( $domain, $group );
    return $self->getEntryAsHashRef( $dn, "objectclass=ispmanMailGroup",
        [ "cn", "mailLocalAddress", "mailForwardingAddress", "mailAlias" ] );
}

sub update_mail_group {
    my $self = shift;
    my ( $domain, $group, $members, $aliases ) = @_;
    my $dn = $self->getMailGroupDN( $domain, $group );
    my $data = {};
    $data->{'mailForwardingAddress'} = $members;
    $data->{'mailAlias'}             = $aliases;
    $self->updateEntryWithData( $dn, $data );
}

sub updateMailGroup {
    my $self = shift;
    my $r    = shift;

    my $dn = $self->getMailGroupDN( $r->param("ispmanDomain"), $r->param("mailGroup") );

    my $data = {};
    $data->{'cn'}                    = $r->param("mailGroup");
    $data->{'mailForwardingAddress'} =
      [ split( /\s+/, $r->param("mailForwardingAddress") ) ];
    $data->{'mailAlias'} = [ split( /\s+/, $r->param("mailAlias") ) ];
    $self->updateEntryWithData( $dn, $data );
    print $self->refreshSignal( $r->param("ispmanDomain") );
    print "Mail group updated<br>";

    $self->editMailGroup($r);
}

sub deleteMailGroup {
    my $self = shift;
    my $r    = shift;
    $self->removeMailGroup( $r->param("ispmanDomain"), $r->param("cn") );
    print "Mailgroup deleted";
    print $self->refreshSignal( $r->param("ispmanDomain") );
}

sub delete_mail_group {
    my $self = shift;
    return $self->removeMailGroup(@_);
}

sub removeMailGroup {
    my $self = shift;
    my ( $domain, $cn ) = @_;
    my $dn = $self->getMailGroupDN( $domain, $cn );
    return $self->deleteEntry($dn);
}

1;
__END__

