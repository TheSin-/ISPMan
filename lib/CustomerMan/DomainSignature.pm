package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub getDomainSignature() {
    my $self   = shift;
    my $domain = $self->{'domain'};
    my $entry  =
      $self->{'ispman'}->{'ldap'}
      ->getEntryAsHashRef( $self->{'domaindn'}, "uid=$domain",
        ["ispmanDomainSignature"] );
    return $entry->{'ispmanDomainSignature'};
}

sub changeDomainSignature {
    my $self = shift;
    my $r    = shift;
    my $dn   = $self->{'domaindn'};
    $self->updateEntryWithData( $dn,
        { "ispmanDomainSignature" => $r->param("ispmanDomainSignature") } );
    $r->param( "mode",    "advanceItems" );
    $r->param( "message", "Signature changed" );
    $r->param( "section", "DomainSignature" );
    $self->advanceItems($r);
}

1;

__END__

