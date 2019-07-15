for (<conf*_vars.ldif>) {
    $moduleName = $_;
    $moduleName =~ s/conf\.//;
    $moduleName =~ s/\.ldif//;
    print "\$Config->{'ispmanVarSort'}{'$moduleName'}=[";

    open F, "$_";
    @vars = grep ( /^ispmanVar:/, <F> );
    close F;
    @_vars = ();

    for $var (@vars) {
        chomp($var);
        $var =~ s/^ispmanVar:\s*//;
        push @_vars, $var;
    }
    print join ",", map { "'$_'" } @_vars;

    print "];\n";
}

