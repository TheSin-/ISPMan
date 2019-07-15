sub UpdateDatabase_task {
    my $params = shift;

    my $dbType = $params->{'old_ispmanDBType'};

    # require our http interface library
    require "database.$dbType.lib";

    # detect db move
    if ($params->{'old_ispmanDBName'} ne $params->{'new_ispmanDBName'}) {
       push @cmd, rename_database($params);
    }

    # get add database command
    push @cmd, update_database($params);
}
