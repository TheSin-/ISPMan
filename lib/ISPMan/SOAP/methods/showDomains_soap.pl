sub showDomains_soap {

    my $type = shift;

    $filters = {
        'primary' => 'ispmanDomainType=primary',
        'slave'   => 'ispmanDomainType=slave',
        'nodns'   => 'ispmanDomainType=nodns',
        'replica' => 'ispmanDomainType=replica'
    };

    my $domains =
      $ispman->makeDomainHash( $ispman->getDomains( $filters->{$type} ) );
	my $_text="";
    for ( keys %$domains ) {
        $_text.="$_\n";
    }
	return $_text;
}

