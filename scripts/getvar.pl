if ( -e "tmp" ) {
    require "tmp/vars.pl";
    print $VAR1->{ $ARGV[0] }{'default'};
}
exit(0);

