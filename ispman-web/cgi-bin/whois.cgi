#!/usr/bin/perl
BEGIN {
    use FindBin;
    unshift @INC, ( $FindBin::Bin, "$FindBin::Bin/../lib" );
}
use Net::XWhois;
my $domain = $ENV{'QUERY_STRING'} || shift;

my $whois = new Net::XWhois Domain => $domain;
if ( $ENV{'QUERY_STRING'} ) {
    print "Content-type: text/html\n\n";
    print qq|
   <head>
   <title>Whois for domain: $domain</title>
   <LINK HREF="/ispman.css" REL="stylesheet" TYPE="text/css">
   </head><body bgcolor=white><pre>|;
}
print $whois->response;

