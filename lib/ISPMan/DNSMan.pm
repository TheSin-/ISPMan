
=head1 NAME
ISPMan::DNSMan - Wrapper for ISPMan::DNSMan::*



=head1 SYNOPSIS

   Initially I started to put all DNS related data in this module
   , now this module is is split into 
     ISPMan::DNSMan::Arecords;
     ISPMan::DNSMan::MXrecords;
     ISPMan::DNSMan::SOArecords;
     ISPMan::DNSMan::NSrecords;
     ISPMan::DNSMan::CNAMES;

   Normally you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


This module is simply a wrapper and does absolutely nothing.

It will go away in future unless it starts doing something useful.



=cut

package ISPMan::DNSMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;

use ISPMan::DNSMan::Arecords;
push @EXPORT, @ISPMan::DNSMan::Arecords::EXPORT;

use ISPMan::DNSMan::AAAArecords;
push @EXPORT, @ISPMan::DNSMan::AAAArecords::EXPORT;

use ISPMan::DNSMan::MXrecords;
push @EXPORT, @ISPMan::DNSMan::MXrecords::EXPORT;

use ISPMan::DNSMan::SOArecords;
push @EXPORT, @ISPMan::DNSMan::SOArecords::EXPORT;

use ISPMan::DNSMan::NSrecords;
push @EXPORT, @ISPMan::DNSMan::NSrecords::EXPORT;

use ISPMan::DNSMan::CNAMES;
push @EXPORT, @ISPMan::DNSMan::CNAMES::EXPORT;

use ISPMan::DNSMan::TXTrecords;
push @EXPORT, @ISPMan::DNSMan::TXTrecords::EXPORT;

use ISPMan::DNSMan::LDIFUtils;
push @EXPORT, @ISPMan::DNSMan::LDIFUtils::EXPORT;

@ISA = qw(Exporter AutoLoader);
push @EXPORT, qw(
  getRevIPs
  newDNSRecord

  getARecordDn
  getARecordBranchDn

  getaAAARecordDn
  getaAAARecordBranchDn
  
  deleteDNSRecord

  addVhostDNSRecord
  deleteVhostDNSRecord

  getcNAMERecordDn
  getcNAMERecordBranchDn

  getmXRecordDn
  getmXRecordBranchDn

  getnSRecordDn
  getnSRecordBranchDn

  gettXTRecordDn
  gettXTRecordBranchDn

  getsOARecordDn
  getDNSDN
);
$VERSION = '0.01';

sub getDNSDN {
    my $self     = shift;
    my $domain   = shift;
    my $dcObject = $self->getDomainAsDCObject($domain);
    my $dnsdn = join( ",", $dcObject, "ou=DNS", $self->getConf('ldapBaseDN') );
    return $dnsdn;
}

sub getsOARecordDn {
    my $self   = shift;
    my $domain = shift;
    return "ou=sOARecord," . $self->getDNSDN($domain);
}

sub getcNAMERecordDn {
    my $self = shift;
    my ( $domain, $host, $alias ) = @_;
    return join ",",
      (
        "relativeDomainName=$alias",
        $self->getcNAMERecordBranchDn( $domain, $host )
      );
}

sub getcNAMERecordBranchDn {
    my $self = shift;
    my ( $domain, $host ) = @_;
    return join ",",
      ( "cNAMERecord=$host, ou=cNAMERecord", $self->getDNSDN($domain) );
}

sub getmXRecordDn {
    my $self = shift;
    my ( $domain, $origion, $pref, $host ) = @_;
    return join ",",
      (
        "relativeDomainName=$origion",
        $self->getmXRecordBranchDn( $domain, $pref, $host )
      );
}

sub getmXRecordBranchDn {
    my $self = shift;
    my ( $domain, $pref, $host ) = @_;
    return join ",",
      ( "mXRecord=$pref $host, ou=mXRecord", $self->getDNSDN($domain) );
}

sub getARecordDn {
    my $self = shift;
    my ( $domain, $host, $ip ) = @_;
    return join ",",
      ( "relativeDomainName=$host", $self->getARecordBranchDn( $domain, $ip ) );
}

sub getARecordBranchDn {
    my $self = shift;
    my ( $domain, $ip ) = @_;
    return join ",", ( "aRecord=$ip, ou=aRecord", $self->getDNSDN($domain) );
}

sub getaAAARecordDn {
    my $self = shift;
    my ( $domain, $host, $ip ) = @_;
    return join ",",
      ( "relativeDomainName=$host", $self->getaAAARecordBranchDn( $domain, $ip ) );
}

sub getaAAARecordBranchDn {
    my $self = shift;
    my ( $domain, $ip ) = @_;
    return join ",", ( "aAAARecord=$ip, ou=aAAARecord", $self->getDNSDN($domain) );
}

sub getnSRecordDn {
    my $self = shift;
    my ( $domain, $origion, $host ) = @_;
    return join ",",
      (
        "relativeDomainName=$origion",
        $self->getnSRecordBranchDn( $domain, $host )
      );
}

sub getnSRecordBranchDn {
    my $self = shift;
    my ( $domain, $host ) = @_;
    return join ",",
      ( "nsRecord=$host, ou=nsRecord", $self->getDNSDN($domain) );
}

sub gettXTRecordDn {
    my $self = shift;
    my ( $domain, $host, $txt ) = @_;
    return join ",",
      ( "relativeDomainName=$host", $self->gettXTRecordBranchDn( $domain, $txt ) );
}

sub gettXTRecordBranchDn {
    my $self = shift;
    my ( $domain, $txt ) = @_;
    return join ",",
      ( "tXTRecord=$txt, ou=tXTRecord", $self->getDNSDN($domain) );
}


sub newDNSRecord {
    my $self = shift;
    my ( $domain, $recordType, $relativeDomainName, $record, $extraHash ) = @_;
    return unless $relativeDomainName =~ /\S/;
    return unless $record             =~ /\S/;

    my $data = {};
    $data = $extraHash;

    my $branch = join ",",
      ( "$recordType=$record", "ou=$recordType", $self->getDNSDN($domain) );
    my $dn = join ",", ( "relativeDomainName=$relativeDomainName", $branch );
    $data->{'objectClass'} = "dnsZone";
    $data->{$recordType} = $record, $data->{'zoneName'} = $domain;
    $data->{'relativeDomainName'} = $relativeDomainName;

    $self->prepareBranchForDN($branch);
    if ( $self->entryExists($dn) ) {
        return;

        # we should not reach here.
        # I don't know why I added this code, but it was surely some work around,
        # removing temporarily
        # $extraHash->{$recordType}=$record;
        # $self->addData2Entry($dn, {"$recordType" => $record});
    }
    else {
        $self->addNewEntryWithData( $dn, $data );
    }
    $self->touchSOA($domain)
      unless $recordType eq
      "sOARecord";    # don't change SOA record, if we are actually changing SOA
    $self->modifyDnsProcess($domain);

}

sub deleteDNSRecord {
    my $self = shift;
    my ( $domain, $recordType, $relativeDomainName, $record, $extraHash ) = @_;

    return unless $relativeDomainName =~ /\S/;
    return unless $record             =~ /\S/;

    my $data = {};
    $data = $extraHash;

    my $branch = join ", ",
      ( "$recordType=$record", "ou=$recordType", $self->getDNSDN($domain) );
    my $dn = join ",", ( "relativeDomainName=$relativeDomainName", $branch );
    if ( $self->entryExists($dn) ) {
        $self->deleteEntry($dn);

        # Lets see if the branch exists and has only one entry. Itself
        if ( $self->entryExists($branch) == 1 ) {

            #only one entry. so just an empty branch
            #lets cleanup the junk
            $self->deleteEntry($branch);
        }
    }
    else {
        return;
    }
    $self->touchSOA($domain)
      unless $recordType eq
      "sOARecord";    # don't change SOA record, if we are actually changing SOA
    $self->modifyDnsProcess($domain);
}

sub addVhostDNSRecord {
    my $self = shift;

    # Create an A record with just a small differnce
    # set TXTRecord  to ispmanVirtualHost:vhost.domain
    # This tells us that the record was created when creating a vhost
    # It should be deleted when deleting the vhost
    my ( $domain, $vhost, $ip ) = @_;
    my $branch = join ",", ( "ou=aRecord", $self->getDNSDN($domain) );
    my $entry =
      $self->getEntry( $branch, "relativeDomainname=$vhost", [], "sub" );
    if ( !$entry
        or $entry->get_value('tXTRecord') =~ m/ispmanVirtualHost/ )
    {
        $self->newDNSRecord( $domain, "aRecord", $vhost, $ip,
            { 'tXTRecord' => "ispmanVirtualHost:$vhost.$domain" } );
    }
}

sub deleteVhostDNSRecord {
    my $self = shift;

    # given the domain and vhost name
    # lookup entry where
    # TXTRecord is ispmanVirtualHost:vhost.domain
    # Now delete the record if the vhost is being deleted
    my ( $domain, $vhost ) = @_;
    my $branch = $self->getDNSDN($domain);

    #print "Searching on $branch\n";
    #print "Looking for ispmanVirtualHost:$vhost.$domain\n";

    my @entries =
      $self->getEntries( $branch, "txtRecord=ispmanVirtualHost:$vhost.$domain",
        [], 'sub' );
    for (@entries) {
        $self->deleteEntry( $_->dn );
    }

    return $#entries;
}

#forget GlobalDNSVars for now. Will fix it when everything is working with the schema
sub manageGlobalDNSVars {
    my $self     = shift;
    my $template = $self->getTemplate("manageGlobalDNSVars.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

#forget GlobalDNSVars for now. Will fix it when everything is working with the schema
sub updateGlobalDNSVars {
    my $self = shift;
    return unless $self->requiredAdminLevel(100);

    my $r    = shift;
    my $data = {};
    for (qw(mxrecord arecord nsrecord cname)) {
        push @{ $data->{$_} }, $r->param($_);
    }
    $self->updateEntryWithData(
        "cn=globaldnsvars, ou=conf, @{[$self->getConf('ldapBaseDN')]}", $data );
    $self->manageGlobalDNSVars;
}

sub getRevIPs {
    my $self = shift;
    my $rev;

    my $ips = $self->getEntriesAsHashRef(
        $self->getConf("ldapBaseDN"),
        '&(pTRRecord=*)(objectclass=dnsZone)',
        [ "zoneName", "relativeDomainName", "pTRRecord" ]
    );
    for ( keys %$ips ) {
        my $ip     = $ips->{$_}{"pTRRecord"};
        my $host   = $ips->{$_}{"relativeDomainName"};
        my $domain = $ips->{$_}{"zoneName"};

        $rev->{$ip} = $self->make_fqdn( $host, $domain );
    }
    return $rev;
}

1;

__END__
   
