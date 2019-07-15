package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub getMailingLists {
    my $self = shift;
    my $r    = shift;
    return $self->{'ispman'}->getMailGroups( $self->{'domaindn'} );
}

sub deleteMailingList {
    my $self = shift;
    my $r    = shift;
    $self->removeMailGroup( $r->param("ispmanDomain"), $r->param("cn") );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "MailingLists" );
    $self->advanceItems($r);
}

sub updateMailingList {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    $self->updateEntryWithData(
        $dn,
        {
            'mailForwardingAddress' =>
              $self->as_arrayref( $r->param("mailForwardingAddress") )
        }
    );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "MailingLists" );
    $r->delete('dn');
    $self->advanceItems($r);
}

sub addMailingList {
    my $self = shift;
    my $r    = shift;
    $r->param( "ispmanDomain", $self->{'domain'} );

    # Break the list into a scalar where each email is separated by space char
    my $addresses = $self->as_arrayref( $r->param('mailForwardingAddress') );
    $r->param( 'mailForwardingAddress', ( join ' ', @$addresses ) );

    $self->addMailGroup($r);

    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "MailingLists" );
    $self->advanceItems($r);
}

1;

__END__

