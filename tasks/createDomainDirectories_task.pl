sub createDomainDirectories_task {
	my $params=shift;

        push @cmd, "mkdir -p $params->{'homeDirectory'}";
        push @cmd, "mkdir -p $params->{'homeDirectory'}/vhosts";
        push @cmd, "mkdir -p $params->{'homeDirectory'}/users";
        push @cmd, "chown -R $params->{'uidNumber'}.$params->{'gidNumber'} $params->{'homeDirectory'}";
       
}

