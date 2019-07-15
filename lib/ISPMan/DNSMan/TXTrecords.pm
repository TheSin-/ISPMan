package ISPMan::DNSMan::TXTrecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  isTXTrecord
  editDNStXTRecords
  addDNStXTRecord
  modifyDNStXTRecord
  deleteDNStXTRecord
  getDNStXTRecords
);
$VERSION = '0.01';

sub isTXTrecord {
    my $self   = shift;
    my $host   = shift;
    my $domain = shift;
    my $branch = join ",", ( "ou=txtRecord", $self->getDNSDN($domain) );
    my $filter = "relativeDomainName=$host";

    if ( $self->getConfig("debug") > 2 ) {
        print qq|
           ISPMan::DNSMan::TXTrecords->isTXTrecord

           Getting input:
           host: $host
           domain: $domain
           
           Calculating:
           branch: $branch
           filter:$filter
           |;
        print "EntryExists: ", $self->entryExists( $branch, $filter );
    }

    return $self->entryExists( $branch, $filter );
}

sub getDNStXTRecords {
    my $self               = shift;
    my $domain             = shift;
    my $relativeDomainName = shift;
    my $filter = "&(objectclass=dnsZone)(txtRecord=*)";
    if ($relativeDomainName) {
        $filter .= "(relativeDomainName=$relativeDomainName)";
    }
    
    my $dn = "ou=txtRecord,".$self->getDNSDN($domain);

    my $h =
      $self->getEntriesAsHashRef( $dn, $filter,
        [ "txtRecord", "relativeDomainName" ] );

    my $records;
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};
    for my $hdn ( sort keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'tXTRecord'} );
        for (@$records) {

            push @{ $self->{'domain'}{'dns'} },
              {
                'host' => $h->{$hdn}{'relativeDomainName'},
		        'ttl'  => $h->{$hdn}{'DNSTTL'},
                'txt'   => $_
              };
        }
    }
    return $self->{'domain'}{'dns'};

}

sub editDNStXTRecords {
    my $self = shift;
    my $r    = shift;

    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );

    $self->getDNStXTRecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_TXTrecords.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_TXTrecords.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub modifyDNStXTRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    # delete old record
    $self->deleteEntry( $r->param("dn") );

    # add record
    $self->addDNStXTRecord($r);
}

sub deleteDNStXTRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    my $entry = $self->getEntry( $dn );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "txtRecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("txtRecord")
    );
    $self->editDNStXTRecords($r);
}

sub addDNStXTRecord {
    my $self      = shift;
    my $r         = shift;
    my $extraHash = {};

    $self->newDNSRecord( $r->param("ispmanDomain"),
            "txtRecord", $r->param("host"), $r->param("txt") );
    $self->editDNStXTRecords($r);
}

1;
__END__

