#!/usr/bin/perl
while (<>) {
    chomp;        #remove the line break
    s/\s+$//g;    #remove any leading spaces.
    $f .= "$_\n"; #put the line break back
}

#remove extra lines else the ldif will not work.
$f =~ s/dn:/\ndn:/g;
$f =~ s/\n\n\n+?dn/\n\ndn/g;
$f =~ s/^\n//g;
chomp($f);
print $f;

