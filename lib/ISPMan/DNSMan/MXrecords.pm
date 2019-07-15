package ISPMan::DNSMan::MXrecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  editDNSmXRecords
  modifyDNSmXRecord
  addDNSmXRecord
  deleteDNSmXRecord
  getDNSmXRecords
  getFirstMX
);
$VERSION = '0.01';

sub getDNSmXRecords {
    my $self   = shift;
    my $domain = shift;

    my $dn = $self->getDNSDN($domain);
    my $h  = $self->getEntriesAsHashRef(
        $dn,
        "&(objectclass=dnsZone)(mXRecord=*)",
        [ "mXRecord", "relativeDomainName" ]
    );
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};

    my $records = ();

    for my $hdn ( keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'mXRecord'} );

        for (@$records) {
            my ( $pref, $host ) = split( /\s\s*/, $_ );
            push @{ $self->{'domain'}{'dns'} },
              {
                'origion' => $h->{$hdn}{'relativeDomainName'},
                'ttl'  => $h->{$hdn}{'DNSTTL'},
                'pref'    => $pref,
                'host'    => $host
              };
        }
    }

    return $self->{'domain'}{'dns'};
}

sub editDNSmXRecords {
    my $self = shift;
    my $r    = shift;

    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );
    $self->getDNSmXRecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_MXrecords.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_MXrecords.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub addDNSmXRecord {
    my $self = shift;
    my $r    = shift;
    $self->newDNSRecord( $r->param("ispmanDomain"),
        "mXRecord", $r->param("origion"), join " ",
        ( $r->param("pref"), $r->param("host") ) );
    $self->editDNSmXRecords($r);
}

sub modifyDNSmXRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    # delete old record
    $self->deleteEntry( $dn );

    # add record
    $self->addDNSmXRecord($r);
}

sub deleteDNSmXRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    my $entry = $self->getEntry( $dn );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "mXRecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("mXRecord")
    );
    $self->editDNSmXRecords($r);
}

sub getFirstMX {
    my $self      = shift;
    my $domain    = shift;
    my $mxrecords = $self->getDNSmXRecords($domain);
    return unless $mxrecords;    # don't bother to sort if there is no records

# sort mx array, so origin record (@) with highest priority (lowest value) is at top
    my @sorted = sort {
             $a->{'origion'} cmp $b->{'origion'}
          || $a->{'pref'} <=> $b->{'pref'}
    } @$mxrecords;

    return $sorted[0]{'host'};
}

1;
__END__

