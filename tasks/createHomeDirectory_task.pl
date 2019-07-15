sub createHomeDirectory_task {
	my $params=shift;

        push @cmd, "mkdir -p $params->{'homeDirectory'}";
        push @cmd, "mkdir -p $params->{'homeDirectory'}/public_html";
        push @cmd, "chown -R $params->{'uidNumber'}.$params->{'gidNumber'} $params->{'homeDirectory'}";
       
}

