#!/usr/bin/perl
sub DeleteVirtualHost_task {
    my $params = shift;

    unless ( $params->{'domain'} ) {
        print STDERR "Domain not defined. Cannot continue\n";
        return 0;
    }
    unless ( $params->{'ispmanVhostName'} ) {
        print STDERR "Vhostname not defined. Cannot continue\n";
        return 0;
    }

    # require our http interface library
    require "http.lib";
    
    # delete vhost config
    delete_vhost( $params->{'ispmanVhostName'}, $params->{'domain'} );

    # generate webserver configuration
    make_vhosts_conf( $params->{'domain'} );

    # reload webserver
    return reloadServer();

}
