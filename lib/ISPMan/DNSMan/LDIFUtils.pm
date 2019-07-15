package ISPMan::DNSMan::LDIFUtils;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  make_ldif_aRecord
  make_ldif_aAAARecord
  make_ldif_mXRecord
  make_ldif_nSRecord
  make_ldif_cNAMERecord
  make_ldif_sOARecord
);
$VERSION = '0.01';

sub make_ldif_aRecord {
    my $self = shift;
    my ( $domain, $host, $ip ) = @_;
    $self->prepareBranchForDN( $self->getARecordBranchDn( $domain, $ip ) );
    my $dn = $self->getARecordDn( $domain, $host, $ip );
    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: $host",
            "zoneName: $domain",
            "aRecord: $ip"
        )
    );
    return $ldif;
}

sub make_ldif_aAAARecord {
    my $self = shift;
    my ( $domain, $host, $ip ) = @_;
    $self->prepareBranchForDN( $self->getaAAARecordBranchDn( $domain, $ip ) );
    my $dn = $self->getaAAARecordDn( $domain, $host, $ip );
    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: $host",
            "zoneName: $domain",
            "aAAARecord: $ip"
        )
    );
    return $ldif;
}

sub make_ldif_mXRecord {
    my $self = shift;
    my ( $domain, $origion, $pref, $host ) = @_;
    $self->prepareBranchForDN(
        $self->getmXRecordBranchDn( $domain, $pref, $host ) );
    my $dn = $self->getmXRecordDn( $domain, $origion, $pref, $host );
    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: $origion",
            "zoneName: $domain",
            "mXRecord: $pref $host"
        )
    );
    return $ldif;
}

sub make_ldif_nSRecord {
    my $self = shift;
    my ( $domain, $origion, $host ) = @_;
    $self->prepareBranchForDN( $self->getnSRecordBranchDn( $domain, $host ) );
    my $dn = $self->getnSRecordDn( $domain, $origion, $host );
    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: $origion",
            "zoneName: $domain",
            "nSRecord: $host"
        )
    );
    return $ldif;
}

sub make_ldif_cNAMERecord {
    my $self = shift;
    my ( $domain, $host, $alias ) = @_;
    $self->prepareBranchForDN(
        $self->getcNAMERecordBranchDn( $domain, $host ) );
    my $dn = $self->getcNAMERecordDn( $domain, $host, $alias );
    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: $alias",
            "zoneName: $domain",
            "cNAMERecord: $host"
        )
    );
    return $ldif;
}

sub make_ldif_sOARecord {
    my $self = shift;
    my ( $domain, $refresh, $retry, $expire, $min ) = @_;
    my $record = join(
        " ",
        (
            $self->staticHost( $self->getConf("primaryDNS") ),
            $self->staticHost( $self->getConf("dnsMasterEmail") ),
            time(),
            $refresh,
            $retry,
            $expire,
            $min
        )
    );

    my $branch = join ",",
      ( "sOARecord=$record", $self->getsOARecordDn($domain) );

    #print "Branch: $branch\n";

    $self->prepareBranchForDN($branch);
    my $dn = join ',', ( 'relativeDomainName=@', $branch );

    my $ldif = join(
        "\n",
        (
            "dn: $dn",
            "objectClass: top",
            "objectClass: dnsZone",
            "relativeDomainName: @",
            "zoneName: $domain",
            "sOARecord: $record"
        )
    );
    return $ldif;

    #print "DN: $dn\n";

    return;

}

