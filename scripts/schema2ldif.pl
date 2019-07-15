#!/usr/bin/perl

use Getopt::Std;
getopts( 't:f:', \%opts );

unless ( $opts{'f'}) {
    print "Usage: $0 [-t type] -f schema_file\n";
    print "type: ibm|opends\n";
    exit;
}

$vendor = $opts{'t'} || "opends";

# vendor definitions
my %templ;
$templ{opends} = {
  header => "dn: cn=schema\nobjectClass: top\nobjectClass: ldapSubentry\nobjectClass: subschema\ncn: schema\n",
  attr   => "attributeTypes:",
  objc   => "objectClasses:"
};

$templ{ibm} = {
  header => "",
  attr   => "attributeTypes=",
  objc   => "objectClasses="
};



if (!defined($templ{$vendor})) {
   die "Error: Unknown vendor \"$vendor\"\n";
}

open(SCHEMA,"<$opts{'f'}") || die "Error: Unable to open \"$opts{'f'}\"\n";

print $templ{$vendor}->{header};

$c = -1;
for (<SCHEMA>) {
    s/^ //g;
    next unless /\S/;
    next if /^#/;

    #print;
    if (/^\s*objectclass/i) {
        $c++;
        $type = "objectclass";
    }
    if (/^\s*attributetype/i) {
        $c++;
        $type = "attribute";
    }

    $data->{$type}[$c] .= $_;
}


for $type ( keys %$data ) {
    $array = $data->{$type};
  ELEMENT: for $element (@$array) {
        $element =~ s/\n/ /g;
        $element =~ s/\t/ /g;
        $element =~ s/\x0d//g;
        $element =~ s/ {2}/ /g;

        $element =~ s/^objectclass\s*\(\s*/$templ{$vendor}->{objc} ( /gi;
        $element =~ s/^attributetype\s*\(\s*/$templ{$vendor}->{attr} ( /gi;
        $element =~ s/ $//g;
        $element =~ s/\)$/ \)/;
        next ELEMENT unless $element =~ /\S/;
        print "$element\n";
    }
}

