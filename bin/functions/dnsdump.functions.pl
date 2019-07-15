#!/usr/bin/perl

sub dump_ns {
    my $domain    = shift;
    my $nsrecords = $ispman->getDNSnSRecords($domain);

    for (@$nsrecords) {
        print join " ", ( "NS", $domain, $_->{'origion'}, $_->{'host'} );
        print "\n";
    }
}

sub dump_mx {
    my $domain    = shift;
    my $mxrecords = $ispman->getDNSmXRecords($domain);

    for (@$mxrecords) {
        print join " ",
          ( "MX", $domain, $_->{'origion'}, $_->{'pref'}, $_->{'host'} );
        print "\n";

    }
}

sub dump_a {
    my $domain   = shift;
    my $arecords = $ispman->getDNSaRecords($domain);
    for (@$arecords) {
        print join " ", ( "A", $domain, $_->{'host'}, $_->{'ip'} );
        print "\n";
    }
}

sub dump_aaaa {
    my $domain   = shift;
    my $arecords = $ispman->getDNSaAAARecords($domain);
    for (@$arecords) {
        print join " ", ( "AAAA", $domain, $_->{'host'}, $_->{'ip'} );
        print "\n";
    }
}

sub dump_cname {
    my $domain = shift;
    my $cnames = $ispman->getDNScNAMERecords($domain);
    for (@$cnames) {
        print join " ", ( "CNAME", $domain, $_->{'alias'}, $_->{'host'} );
        print "\n";
    }
}

sub dump_soa {
    my $domain = shift;
    my $soa    = $ispman->getSOA($domain);
    print join " ",
      (
        "SOA", $domain, $soa->{'primary'}, $soa->{'rootmail'},
        $soa->{'refresh'}, $soa->{'retry'}, $soa->{'expire'}, soa->{'minimum'}
      );
    print "\n";
}

sub dump_all {
    return dump_any(@_);
}

sub dump_any {
    &dump_soa(@_);
    &dump_ns(@_);
    &dump_mx(@_);
    &dump_a(@_);
    &dump_cname(@_);
}

1;

