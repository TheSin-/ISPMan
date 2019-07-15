#!/usr/bin/perl
require "tmp/vars.pl";
for (<>) {
    s/%%(\w+)?%%/$VAR1->{$1}{'default'}/g;
    s/\@\@(randcrypt.*?)\@\@/eval($1)/ge;
    print;
}

sub randcrypt {
    my $string = shift;

    #print "Getting $string\n\n";
    return
      crypt( $string, join '',
        ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ] );
}

