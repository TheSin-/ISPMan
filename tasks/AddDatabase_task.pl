sub AddDatabase_task {
    my $params = shift;

    my $dbType = $params->{'ispmanDBType'};

    # require our http interface library
    require "database.$dbType.lib";

    # get add database command
    push @cmd, add_database($params);
}
