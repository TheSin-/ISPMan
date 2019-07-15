#!/usr/bin/perl

BEGIN {
use FindBin;
unshift @INC,
  ( "$FindBin::Bin../bin", "$FindBin::Bin/../lib", "$FindBin::Bin/../conf" );
}

use ISPMan;
my $domain = shift @ARGV;

my $ispman = ISPMan->new();

my $domainInfo = $ispman->getDomainInfo($domain);

system( "$FindBin::Bin/../bin/ispman.dnsset -d $domain -t A mail "
      . $domainInfo->{'ispmanDomainDefaultMailDropHost'} );

