#!/usr/bin/perl

use FindBin;
unshift @INC,
  ( "$FindBin::Bin../bin", "$FindBin::Bin/../lib", "$FindBin::Bin/../conf" );

my $domain = $ARGV[0];

system("$FindBin::Bin/../bin/ispman.addvhost -d $domain www");

