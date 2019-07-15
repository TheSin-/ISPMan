#!/usr/bin/perl

sub show_ns {
    my $domain    = shift;
    my $nsrecords = $ispman->getDNSnSRecords($domain);

    for (@$nsrecords) {
        print join "\t", ( $_->{'origion'}, "IN", "NS", $_->{'host'} );
        print "\n";
    }
}

sub show_mx {
    my $domain    = shift;
    my $mxrecords = $ispman->getDNSmXRecords($domain);

    for (@$mxrecords) {
        print join "\t",
          ( $_->{'origion'}, "IN", "MX", $_->{'pref'}, $_->{'host'} );
        print "\n";

    }
}

sub show_a {
    my $domain = shift;
    my $arecords = $ispman->getDNSaRecords( $domain, @ARGV );
    for (@$arecords) {
        print join "\t", ( $_->{'host'}, "IN", "A", $_->{'ip'} );
        print "\n";
    }
}

sub show_aaaa {
    my $domain = shift;
    my $arecords = $ispman->getDNSaAAARecords( $domain, @ARGV );
    for (@$arecords) {
        print join "\t", ( $_->{'host'}, "IN", "AAAA", $_->{'ip'} );
        print "\n";
    }
}

sub show_cname {
    my $domain = shift;
    my $cnames = $ispman->getDNScNAMERecords($domain);
    for (@$cnames) {
        print join "\t", ( $_->{'alias'}, "IN", "CNAME", $_->{'host'} );
        print "\n";
    }
}

sub show_txt {
    my $domain = shift;
    my $txtrecords = $ispman->getDNStXTRecords( $domain, @ARGV );
    for (@$txtrecords) {
        print join "\t", ( $_->{'host'}, "IN", "TXT", $_->{'txt'} );
        print "\n";
    }
}

sub show_soa {
    my $domain = shift;
    my $soa    = $ispman->getSOA($domain);
    print "@ IN SOA $soa->{'primary'}  $soa->{'rootmail'} (\n";
    for (qw(serial refresh retry expire minimum)) {
        print "\t $soa->{$_} ; $_\n";
    }
    print ")\n\n";
}

sub show_all {
    return show_any(@_);
}

sub show_any {
    &show_soa(@_);
    print "\n\n";
    &show_ns(@_);
    print "\n\n";
    &show_mx(@_);
    print "\n\n";
    &show_a(@_);
    print "\n\n";
    &show_aaaa(@_);
    print "\n\n";
    &show_txt(@_);
    print "\n\n";
    &show_cname(@_);
}

1;

