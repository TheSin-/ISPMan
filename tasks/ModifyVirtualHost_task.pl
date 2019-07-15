sub ModifyVirtualHost_task {
    my $params = shift;
    unless ( $params->{'domain'} ) {
        print STDERR "Domain not defined. Cannot continue\n";
        return 0;
    }
    unless ( $params->{'ispmanVhostName'} ) {
        print STDERR "Vhostname not defined. Cannot continue\n";
        return 0;
    }

    require "http.lib";

    # modify vhost config
    modify_vhost( $params->{'ispmanVhostName'}, $params->{'domain'} );

    # generate configuration
    make_vhosts_conf( $params->{'domain'} );

    # reload webserver
    return reloadServer();

}
