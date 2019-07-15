#!/usr/bin/perl
use vars qw($VAR1 $r $MOD_PERL);
if ( exists $ENV{'GATEWAY_INTERFACE'}
    && ( $MOD_PERL = $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl\// ) )
{
    $| = 1;
    require Apache;
    $r = Apache->request;
    $r->send_cgi_header("Content-type: text/css\n\n");
}
else {
    print "Content-type: text/css\n\n";
}

do "tmpl/customerMan/css.hash";

for ( keys %$VAR1 ) {
    print "$_ {\n";
    for $attr ( keys %{ $VAR1->{$_} } ) {
        print "\t$attr: $VAR1->{$_}{$attr};\n";
    }
    print "}\n\n";
}
