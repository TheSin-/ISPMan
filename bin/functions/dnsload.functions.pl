
sub set_ns {
    my $domain = shift;
    $ispman->newDNSRecord( $domain, "nSRecord", @_ );
}

sub set_mx {
    my $domain = shift;
    $ispman->newDNSRecord( $domain, "mXRecord", $_[0], join " ",
        ( $_[1], $_[2] ) );
}

sub set_a {
    my $domain = shift;
    $ispman->newDNSRecord( $domain, "aRecord", $_[0], $_[1] );
}

sub set_aaaa {
    my $domain = shift;
    $ispman->newDNSRecord( $domain, "aAAARecord", $_[0], $_[1] );
}

sub set_cname {
    my $domain = shift;
    $ispman->newDNSRecord( $domain, "cNAMERecord", $_[0], $_[1] );
}

sub set_soa {
    my $domain = shift;
    my $soa = { 'primary'  => $_[0],
                'rootmail' => $_[1],
                'serial'   => time(),
                'refresh'  => $_[2],
                'retry'    => $_[3],
                'expire'   => $_[4],
                'minimum'  => $_[5] };
    $ispman->setDNSsOARecord( $domain, $soa );
}

1;
