package ISPMan::DNSMan::AAAArecords;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  isAAAArecord
  editDNSaAAARecords
  addDNSaAAARecord
  modifyDNSaAAARecord
  deleteDNSaAAARecord
  getDNSaAAARecords
);
$VERSION = '0.01';

sub isAAAArecord {
    my $self   = shift;
    my $host   = shift;
    my $domain = shift;
    my $branch = join ",", ( "ou=aAAARecord", $self->getDNSDN($domain) );
    my $filter = "relativeDomainName=$host";

    if ( $self->getConfig("debug") > 2 ) {
        print qq|
           ISPMan::DNSMan::AAAArecords->isAAAArecord

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

sub getDNSaAAARecords {
    my $self               = shift;
    my $domain             = shift;
    my $relativeDomainName = shift;
    my $filter;
    if ($relativeDomainName) {
        $filter =
"&(objectclass=dnsZone)(aAAARecord=*)(relativeDomainName=$relativeDomainName)";
    }
    else {
        $filter = "&(objectclass=dnsZone)(aAAARecord=*)";
    }
    my $dn = $self->getDNSDN($domain);

    my $h =
      $self->getEntriesAsHashRef( $dn, $filter,
        [ "aAAARecord", "relativeDomainName", "pTRRecord" ] );

    my $records;
    $self->{'domain'}{'dns'} = ();
    undef $self->{'domain'}{'dns'};
    for my $hdn ( sort keys %$h ) {
        $records = $self->as_arrayref( $h->{$hdn}{'aAAARecord'} );
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

sub editDNSaAAARecords {
    my $self = shift;
    my $r    = shift;

    return
      unless $self->checkDomainType( $r->param("ispmanDomain"), "primary" );
    $self->{'domain'} = $self->getDomainInfo( $r->param("ispmanDomain") );

    $self->getDNSaAAARecords( $r->param("ispmanDomain") );

    my $template = "";
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("dns/edit_AAAArecords.tmpl");
    }
    else {
        $template = $self->getTemplate("dns/view_AAAArecords.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub modifyDNSaAAARecord {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    # delete old record
    $self->deleteEntry( $dn );

    # add record
    $self->addDNSaAAARecord($r);
}
    
sub deleteDNSaAAARecord {   
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    
    my $entry = $self->getEntry( $r->param("dn") );
    $self->deleteDNSRecord(
            $r->param("ispmanDomain"),
            "aAAARecord",
            $entry->get_value("relativeDomainName"),
            $entry->get_value("aAAARecord")
    );
    $self->editDNSaAAARecords($r);    
}

sub addDNSaAAARecord {
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
            "aAAARecord", $r->param("host"), $r->param("ip"), $extraHash );
    }
    $self->editDNSaAAARecords($r);
}

1;
__END__

