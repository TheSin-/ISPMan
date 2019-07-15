
sub set_ns {
    print "$opts{'d'}: Adding NS record @ARGV \n" if defined $opts{'v'};
    $ispman->newDNSRecord( $opts{'d'}, "nSRecord", @ARGV );

    #dns set ns origion  host
}

sub set_mx {
    print "$opts{'d'}: Adding MX record @ARGV \n" if defined $opts{'v'};
    $ispman->newDNSRecord( $opts{'d'}, "mXRecord", $ARGV[0], join " ",
        ( $ARGV[1], $ARGV[2] ) );

    #dns set mx origion pref host
}

sub set_a {
    print "$opts{'d'}: Adding A record @ARGV \n" if defined $opts{'v'};
    print "Also setting a PTR record\n"
      if ( defined $opts{'p'} && defined $opts{'v'} );
    my $extraHash = {};
    $extraHash->{'pTRRecord'} = $ARGV[1] if defined $opts{'p'};
    $ispman->newDNSRecord( $opts{'d'}, "aRecord", $ARGV[0], $ARGV[1],
        $extraHash );

    #dns set a  host ip
}

sub set_aaaa {
    print "$opts{'d'}: Adding AAAA record @ARGV \n" if defined $opts{'v'};
    print "Also setting a PTR record\n"
      if ( defined $opts{'p'} && defined $opts{'v'} );
    my $extraHash = {};
    $extraHash->{'pTRRecord'} = $ARGV[1] if defined $opts{'p'};
    $ispman->newDNSRecord( $opts{'d'}, "aAAARecord", $ARGV[0], $ARGV[1],
        $extraHash );

    #dns set aaaa  host ip
}

sub set_cname {
    print "$opts{'d'}: Adding CNAME record @ARGV \n" if defined $opts{'v'};
    $ispman->newDNSRecord( $opts{'d'}, "cNAMERecord", $ARGV[0], $ARGV[1] );

    #dns set cname alias host
}

sub set_txt {
    print "$opts{'d'}: Adding TXT record @ARGV \n" if defined $opts{'v'};
    $ispman->newDNSRecord( $opts{'d'}, "tXTRecord", @ARGV );
}

sub set_soa {
    my $soa;
    if ( $opts{'s'} ) {
        my ( $var, $val ) = split("=",$opts{'s'});
        print "$opts{'d'}: Set SOA record $var=$val\n" if defined $opts{'v'};
        $soa = $ispman->getSOA( $opts{'d'} );
        $soa->{$var} = $val;
    }
    else {
        print "$opts{'d'}: Set SOA record @ARGV \n" if defined $opts{'v'};

        $soa = {
            'primary'  => $ARGV[0],
            'rootmail' => $ARGV[1],
            'serial'   => time(),
            'refresh'  => $ARGV[2],
            'retry'    => $ARGV[3],
            'expire'   => $ARGV[4],
            'minimum'  => $ARGV[5]
        };
    }

    foreach ('primary', 'rootmail', 'refresh', 'retry', 'expire', 'minimum') {
      if (! defined($soa->{$_})) {
        print "FATAL: the SOA record is incomplete (missing $_). Aborting!\n";
        print "Hint: Add a complete SOA first.\n";
        return;
      }
    }

    $ispman->setDNSsOARecord( $opts{'d'}, $soa );

    #dns set SOA primary rootmail refresh retry expire minimum
}

1;
