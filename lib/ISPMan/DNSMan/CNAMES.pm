package ISPMan::DNSMan::CNAMES;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  isCNAME
  editDNScNAMERecords
  modifyDNScNAMERecord
  deleteDNScNAMERecord
  addDNScNAMERecord
  getDNScNAMERecords
  getCNAMERecordsForHost
);
$VERSION = '0.01';

sub isCNAME {
    my $self   = shift;
    my $host   = shift;
    my $domain = shift;
    my $branch = join ",", ( "ou=cNameRecord", $self->getDNSDN($domain) );
    my $filter = "relativeDomainName=$host";
    return $self->entryExists( $branch, $filter );
}


sub getCNAMERecordsForHost {
    my $self = shift;
    my ( $domain, $host, $extraFilter ) = @_;
    my $dn     = $self->getDNSDN($domain);
    my $filter = "&(objectclass=dnsZone)(cNAMERecord=$host)";
    if ($extraFilter) {
        $filter .= "($extraFilter)";
    }

    my $h = $self->getEntriesAsHashRef( $dn, $filter );
    return $h;

}

sub getDNScNAMERecords {
    my $self   = shift;
    my $domain = shift;
    my $dn     = $self->getDNSDN($domain);
    my $h      = $self->getEntriesAsHashRef(
        $dn,
        "&(objectclass=dnsZone)(cNAMERecord=*)",
        [ "cNAMERecord", "relativeDomainName" ]
    );
    my $records;
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};
    for my $hdn ( sort keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'cNAMERecord'} );
        for (@$records) {
            push @{ $self->{'domain'}{'dns'} },
              {
                'alias' => $h->{$hdn}{'relativeDomainName'},
		'ttl'  => $h->{$hdn}{'DNSTTL'},
                'host'  => $_
              };
        }
    }
    return $self->{'domain'}{'dns'};
}

sub editDNScNAMERecords {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );
    $self->getDNScNAMERecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_CNAMES.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_CNAMES.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub addDNScNAMERecord {
    my $self = shift;
    my $r    = shift;
    if ( $self->isArecord( $r->param("alias"), $r->param("ispmanDomain") ) ) {
        $r->param( "error",
            "ERROR: " . $r->param("alias") . " is defined as an A record" );
    }
    else {
        $self->newDNSRecord(
            $r->param("ispmanDomain"), "cNAMERecord",
            $r->param("alias"),        $r->param("host")
        );
    }
    $self->editDNScNAMERecords($r);
}

sub modifyDNScNAMERecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    # delete old record
    $self->deleteEntry( $dn );

    # add record
    $self->addDNScNAMERecord($r);
}

sub deleteDNScNAMERecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    my $entry = $self->getEntry( $dn );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "cNAMERecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("cNAMERecord")
        );
    $self->editDNScNAMERecords($r);
}

1;
__END__

