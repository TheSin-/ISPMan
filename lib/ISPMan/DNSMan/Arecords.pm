package ISPMan::DNSMan::Arecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  isArecord
  editDNSaRecords
  addDNSaRecord
  modifyDNSaRecord
  deleteDNSaRecord
  getDNSaRecords
);
$VERSION = '0.01';

sub isArecord {
    my $self   = shift;
    my $host   = shift;
    my $domain = shift;
    my $branch = join ",", ( "ou=aRecord", $self->getDNSDN($domain) );
    my $filter = "relativeDomainName=$host";

    if ( $self->getConfig("debug") > 2 ) {
        print qq|
           ISPMan::DNSMan::Arecords->isArecord

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

sub getDNSaRecords {
    my $self               = shift;
    my $domain             = shift;
    my $relativeDomainName = shift;
    my $filter;
    if ($relativeDomainName) {
        $filter =
"&(objectclass=dnsZone)(aRecord=*)(relativeDomainName=$relativeDomainName)";
    }
    else {
        $filter = "&(objectclass=dnsZone)(aRecord=*)";
    }
    my $dn = $self->getDNSDN($domain);

    my $h =
      $self->getEntriesAsHashRef( $dn, $filter,
        [ "aRecord", "relativeDomainName", "pTRRecord" ] );

    my $records;
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};
    for my $hdn ( sort keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'aRecord'} );
        for (@$records) {

            push @{ $self->{'domain'}{'dns'} },
              {
                'host' => $h->{$hdn}{'relativeDomainName'},
		'ttl'  => $h->{$hdn}{'DNSTTL'},
                'ptr'  => $h->{$hdn}{'pTRRecord'},
                'ip'   => $_
              };
        }
    }
    return $self->{'domain'}{'dns'};

}

sub editDNSaRecords {
    my $self = shift;
    my $r    = shift;

    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );

    $self->getDNSaRecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_Arecords.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_Arecords.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub modifyDNSaRecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    # delete old record
    $self->deleteEntry( $dn );

    # add record
    $self->addDNSaRecord($r);
}
    
sub deleteDNSaRecord {   
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    my $entry = $self->getEntry( $r->param("dn") );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "aRecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("aRecord")
    );
    $self->editDNSaRecords($r);    
}

sub addDNSaRecord {
    my $self      = shift;
    my $r         = shift;
    my $extraHash = {};

    if ( $self->isCNAME( $r->param("host"), $r->param("ispmanDomain") ) ) {
        $r->param( "error",
            "ERROR: " . $r->param("host") . " is defined as an CNAME record" );
    }
    else {
        $extraHash->{'pTRRecord'} = $r->param("ip") if $r->param("pTRRecord");
        $self->newDNSRecord( $r->param("ispmanDomain"),
            "aRecord", $r->param("host"), $r->param("ip"), $extraHash );
    }
    $self->editDNSaRecords($r);
}

1;
__END__

