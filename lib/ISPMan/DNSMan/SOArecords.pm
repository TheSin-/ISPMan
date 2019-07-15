package ISPMan::DNSMan::SOArecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  editDNSsOARecords
  modifyDNSsOARecords
  getSOA
  touchSOA
  setDNSsOARecord
  updateSOASerial
);
$VERSION = '0.01';

sub editDNSsOARecords {
    my $self = shift;
    my $r    = shift;

    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );

    $self->{'domain'}{'dns'} = $self->getSOA( $r->param("ispmanDomain") );
    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_SOA.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_SOA.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub modifyDNSsOARecords {
    my $self = shift;
    my $r    = shift;
    my $soa  = $self->getSOA( $r->param('ispmanDomain') );

    foreach ( ('primary','rootmail','refresh','retry','expire','minimum') ){
        $soa->{$_} = $r->param($_);
    }
    $self->setDNSsOARecord( $r->param("ispmanDomain"), $soa );

    $self->editDNSsOARecords($r);
}

sub setDNSsOARecord {
    my $self   = shift;
    my $domain = shift;
    my $soa    = shift;

    $soa->{'serial'} = $self->updateSOASerial( $soa->{'serial'} );
    $self->delTree( $self->getsOARecordDn( $domain ) );
    $self->newDNSRecord( $domain, "sOARecord", '@', join " ",
       ($soa->{'primary'}, $soa->{'rootmail'}, $soa->{'serial'},
        $soa->{'refresh'}, $soa->{'retry'},    $soa->{'expire'},
        $soa->{'minimum'}));
}

sub getSOA {
    my $self   = shift;
    my $domain = shift;

    my $dn  = $self->getsOARecordDn($domain);
    my $soa = {};
    my $h   =
      $self->getEntryAsHashRef( $dn, "objectclass=dnsZone", ["sOARecord"],
        "sub" );

    (
        $soa->{'primary'}, $soa->{'rootmail'}, $soa->{'serial'},
        $soa->{'refresh'}, $soa->{'retry'},    $soa->{'expire'},
        $soa->{'minimum'}
      )
      = split( /\s\s*/, $h->{'sOARecord'} );
    $soa->{'ttl'} = $h->{'DNSTTL'};
    return $soa;
}

sub touchSOA {
    my $self   = shift;
    my $domain = shift;

    my $soa = $self->getSOA($domain);

    $soa->{'serial'} = $self->updateSOASerial( $soa->{'serial'} );

    $self->delTree( $self->getsOARecordDn($domain) );
    $self->setDNSsOARecord( $domain, $soa );
}

sub getDNSnSRecords {
    my $self   = shift;
    my $domain = shift;

    my $dn = $self->getDNSDN($domain);
    my $h  = $self->getEntriesAsHashRef(
        $dn,
        "&(objectclass=dnsZone)(nSRecord=*)",
        [ "nSRecord", "relativeDomainName" ]
    );
}

# updateSOASerial - generates the correct serial for the record.
# correct format: YYYYMMDDnn
sub updateSOASerial {
    my $self   = shift;
    my $serial = shift;

    if ( $self->getConf('dnsSerialFormat') eq 'timestamp' ) {
        return time();
    }

    my @localtime = localtime();
    my $year      = $localtime[5] + 1900;
    my $month     = $localtime[4] + 1;
    my $day       = $localtime[3];

    my $index   = substr( $serial, -2, 2 );
    my $olddate = substr( $serial, 0,  8 );

    $day   = "0$day"   if ( $day < 10 );
    $month = "0$month" if ( $month < 10 );

    my $newdate = $year . $month . $day;

    if ( $olddate ne $newdate ) {
        $serial = $newdate . "01";
    }
    elsif ( $olddate == $newdate ) {
        $index++;
        $serial = $olddate . $index;
    }

    return $serial;
}

1;
__END__

