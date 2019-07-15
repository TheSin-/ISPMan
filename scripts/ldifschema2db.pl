use lib qw(/opt/ispman/lib);
use Data::Dumper;
use Net::LDAP;
use Net::LDAP::Schema;
$schema = Net::LDAP::Schema->new;

$schema->parse( $ARGV[0] ) or die $schema->error;
@attributetypes = $schema->attributes();
@objectclasses  = $schema->objectclasses();

foreach $attr ( @attributetypes, @objectclasses ) {
    $_oid = $schema->name2oid("$attr");
    if ( ref $_oid ne "ARRAY" ) {
        push @$_oid, $_oid;
    }

    foreach $oid (@$_oid) {
        @at_items = $schema->items("$oid");
        foreach $value (@at_items) {
            @item = $schema->item( $oid, $value );

            if ( defined(@item) && $#item >= 0 ) {
                for (@item) {
                    $attributetypeshashref->{$attr}{$value} = $item[0];

                }
            }
        }
    }
}

$Data::Dumper::Terse  = 0;    # don't output names where feasible
$Data::Dumper::Indent = 7;
print Dumper($attributetypeshashref);

