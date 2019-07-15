package ISPMan::DNSMan::NSrecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  editDNSnSRecords
  addDNSnSRecord
  modifyDNSnSRecord
  deleteDNSnSRecord
  getDNSnSRecords
);
$VERSION = '0.01';

sub getDNSnSRecords {
    my $self   = shift;
    my $domain = shift;

    my $dn = $self->getDNSDN($domain);
    my $h  = $self->getEntriesAsHashRef(
        $dn,
        "&(objectclass=dnsZone)(nSRecord=*)",
        [ "nSRecord", "relativeDomainName" ]
    );

    my $records = ();
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};

    for my $hdn ( keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'nSRecord'} );
        for (@$records) {
            push @{ $self->{'domain'}{'dns'} },
              {
                'origion' => $h->{$hdn}{'relativeDomainName'},
                'ttl'  => $h->{$hdn}{'DNSTTL'},
                'host'    => $_
              };
        }
    }

    return $self->{'domain'}{'dns'};

}

sub editDNSnSRecords {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );
    $self->getDNSnSRecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_NSrecords.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_NSrecords.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub modifyDNSnSRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    # delete old record
    $self->deleteEntry( $dn );

    # add record
    $self->addDNSnSRecord($r);
}

sub deleteDNSnSRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    my $entry = $self->getEntry( $dn );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "nSRecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("nSRecord")
    );
    $self->editDNSnSRecords($r);
}

sub addDNSnSRecord {
    my $self = shift;
    my $r    = shift;
    $self->newDNSRecord(
        $r->param("ispmanDomain"), "nSRecord",
        $r->param("origion"),      $r->param("host")
    );
    $self->editDNSnSRecords($r);
}

1;
__END__

