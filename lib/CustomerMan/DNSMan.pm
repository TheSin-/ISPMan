package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub getNSRecords {
    my $self          = shift;
    my $nsrecordslist =
      $self->{'ispman'}
      ->getRecords( "cn=nsrecords, ou=dnsdata, $self->{'domaindn'}",
        "nsrecords" );
    my $nsrecordsHash = {};
    for (@$nsrecordslist) {
        my ( $origion, $host ) = split( /\s*,\s*/, $_ );
        $nsrecordsHash->{$origion} = $host;
    }
}

sub xupdateNSRecords {
    my $self = shift;
    my $r    = shift;
    $r->param( "dn", "cn=nsrecords, ou=dnsdata, $self->{'domaindn'}" );
    $self->{'ispman'}->modifynsrecords( $r, $r->param("dn") );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "DNSSettings" );
    $self->advanceItems($r);
}

sub updateNSRecords {
    my $self = shift;
    my $r    = shift;
    print "Sorry, just fixing some bug<br>";
    print
"Use wrong version of control panel. the API is changed so I have to fix some stuff<br>";
    print $r->as_string;

    #$r->param("dn", "cn=nsrecords, ou=dnsdata, $self->{'domaindn'}");
    #$self->{'ispman'}->modifynsrecords($r, $r->param("dn"));
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "DNSSettings" );
    $self->advanceItems($r);
}

sub updateMXRecords {
    my $self = shift;
    my $r    = shift;
    $r->param( "dn", "cn=mxrecords, ou=dnsdata, $self->{'domaindn'}" );
    $self->{'ispman'}->modifymxrecords( $r, $r->param("dn") );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "DNSSettings" );
    $self->advanceItems($r);
}

sub updateARecords {
    my $self = shift;
    my $r    = shift;
    $r->param( "dn", "cn=arecords, ou=dnsdata, $self->{'domaindn'}" );

    $self->{'ispman'}->modifyarecords( $r, $r->param("dn") );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "DNSSettings" );
    $self->advanceItems($r);
}

sub updateCnames {
    my $self = shift;
    my $r    = shift;
    $r->param( "dn", "cn=cnames, ou=dnsdata, $self->{'domaindn'}" );

    $self->{'ispman'}->modifycnames( $r, $r->param("dn") );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "DNSSettings" );
    $self->advanceItems($r);
}

sub editDNSRecord {
    my $self     = shift;
    my $r        = shift;
    my $type     = $r->param("type");
    my $template = $self->getTemplate("customerMan/dns/$type.tmpl");
    print $template->fill_in();

}

sub addDNSRecord {
    my $self = shift;
    my $r    = shift;
    my $type = $r->param("type");

    if ( $type eq "ns" ) {
        $self->newDNSRecord(
            $self->{'domain'},    "nSRecord",
            $r->param("origion"), $r->param("host")
        );
    }
    if ( $type eq "mx" ) {
        $self->newDNSRecord( $self->{'domain'}, "mXRecord",
            $r->param("origion"), join " ",
            ( $r->param("pref"), $r->param("host") ) );
    }
    if ( $type eq "a" ) {
        $self->newDNSRecord(
            $self->{'domain'}, "aRecord",
            $r->param("host"), $r->param("ip")
        );
    }
    if ( $type eq "cname" ) {
        $self->newDNSRecord(
            $self->{'domain'},  "cNAMERecord",
            $r->param("alias"), $r->param("host")
        );
    }

    #$self->touchSOA($self->{'domain'});
    $r->param( "section", "DNSSettings" );
    $r->delete("dn");
    $r->delete("dns_partial_dn");
    $r->delete("ip");
    $r->delete("pref");
    $r->delete("origion");
    $r->delete("alias");
    $r->delete("hosts");
    $self->advanceItems($r);
}

sub updateDNSRecord {
    my $self = shift;
    my $r    = shift;
    my $type = $r->param("type");
    if ( $type eq "ns" ) {
        my $dn = join(
            "",
            (
                $r->param("dns_partial_dn"),
                $self->getDNSDN( $self->{'domain'} )
            )
        );
        $self->deleteEntry($dn);
        $self->newDNSRecord(
            $self->{'domain'},    "nSRecord",
            $r->param("origion"), $r->param("host")
        );
    }

    if ( $type eq "mx" ) {
        my $dn = join(
            "",
            (
                $r->param("dns_partial_dn"),
                $self->getDNSDN( $self->{'domain'} )
            )
        );
        $self->deleteEntry($dn);
        $self->newDNSRecord( $self->{'domain'}, "mXRecord",
            $r->param("origion"), join " ",
            ( $r->param("pref"), $r->param("host") ) );
    }

    if ( $type eq "a" ) {
        my $dn = join(
            "",
            (
                $r->param("dns_partial_dn"),
                $self->getDNSDN( $self->{'domain'} )
            )
        );
        $self->deleteEntry($dn);
        $self->newDNSRecord(
            $self->{'domain'}, "aRecord",
            $r->param("host"), $r->param("ip")
        );
    }

    if ( $type eq "cname" ) {
        my $dn = join(
            "",
            (
                $r->param("dns_partial_dn"),
                $self->getDNSDN( $self->{'domain'} )
            )
        );
        $self->deleteEntry($dn);
        $self->newDNSRecord(
            $self->{'domain'},  "cNAMERecord",
            $r->param("alias"), $r->param("host")
        );
    }

    $self->touchSOA( $self->{'domain'} );
    $r->param( "section", "DNSSettings" );
    $r->delete("dn");
    $r->delete("dns_partial_dn");
    $r->delete("ip");
    $r->delete("pref");
    $r->delete("origion");
    $r->delete("alias");
    $r->delete("hosts");
    $self->advanceItems($r);

}

sub deleteDNSRecord {
    my $self = shift;
    my $r    = shift;
    my $type = $r->param("type");
    if ( $type eq "ns" ) {
        my $recordDN =
          $self->{'ispman'}
          ->getnSRecordDn( $self->{'domain'}, $r->param("origion"),
            $r->param("host") );
        $self->deleteEntry($recordDN);
    }
    if ( $type eq "mx" ) {
        my $recordDN = $self->{'ispman'}->getmXRecordDn(
            $self->{'domain'}, $r->param("origion"),
            $r->param("pref"), $r->param("host")
        );
        $self->deleteEntry($recordDN);
    }
    if ( $type eq "a" ) {
        my $recordDN =
          $self->{'ispman'}->getARecordDn( $self->{'domain'}, $r->param("host"),
            $r->param("ip") );
        $self->deleteEntry($recordDN);
    }
    if ( $type eq "cname" ) {
        my $recordDN =
          $self->{'ispman'}
          ->getcNAMERecordDn( $self->{'domain'}, $r->param("host"),
            $r->param("alias") );
        $self->deleteEntry($recordDN);
    }
    if ( $type eq "mx" ) {
        my $recordDN = $self->{'ispman'}->getmXRecordDn(
            $self->{'domain'}, $r->param("origion"),
            $r->param("pref"), $r->param("host")
        );
        $self->deleteEntry($recordDN);
    }

    $self->touchSOA( $self->{'domain'} );
    $r->param( "section", "DNSSettings" );
    $r->delete("dn");
    $r->delete("dns_partial_dn");
    $r->delete("ip");
    $r->delete("pref");
    $r->delete("origion");
    $r->delete("hosts");
    $self->advanceItems($r);
}

sub remove_parent_dn {

    # remove the domain part etc.
    # we don't want someone to hack another domain than their own.
    my $self = shift;
    my ( $domain, $recordDN ) = @_;
    my $dnsDN = $self->getDNSDN( $self->{'domain'} );
    $recordDN =~ s/\s*,\s*/,/g;
    $dnsDN    =~ s/\s*,\s*/,/g;
    $recordDN =~ s/$dnsDN//;
    return $recordDN;
}

sub getCustomer_nSRecordDn {
    my $self = shift;
    return $self->remove_parent_dn( $self->{'domain'},
        $self->{'ispman'}->getnSRecordDn( $self->{'domain'}, @_ ) );
}

sub getCustomer_mXRecordDn {
    my $self = shift;
    return $self->remove_parent_dn( $self->{'domain'},
        $self->{'ispman'}->getmXRecordDn( $self->{'domain'}, @_ ) );
}

sub getCustomer_ARecordDn {
    my $self = shift;
    return $self->remove_parent_dn( $self->{'domain'},
        $self->{'ispman'}->getARecordDn( $self->{'domain'}, @_ ) );
}

sub getCustomer_cNAMERecordDn {
    my $self = shift;
    return $self->remove_parent_dn( $self->{'domain'},
        $self->{'ispman'}->getcNAMERecordDn( $self->{'domain'}, @_ ) );
}

1;

__END__

