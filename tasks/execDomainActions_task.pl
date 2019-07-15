sub execDomainActions_task {
    my $params = shift;
    unless ( $params->{'domain'} ) {
        print STDERR "Domain not defined. Cannot continue\n";
        return 0;
    }
    unless ( $params->{'script'} ) {
        print STDERR "script not defined. Cannot continue\n";
        return 0;
    }

    push @cmd, "$FindBin::Bin/../tasks/$params->{'script'} $params->{'domain'}";
}
