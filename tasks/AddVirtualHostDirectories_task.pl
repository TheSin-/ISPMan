sub AddVirtualHostDirectories_task {
	my $params=shift;


        $homeDirectory=$params->{'homeDirectory'};

        $document_root=($params->{'ispmanVhostDocumentRoot'}=~m!^/!)?$params->{'ispmanVhostDocumentRoot'}: join "/", ($homeDirectory, $params->{'ispmanVhostDocumentRoot'});
        $script_dir=($params->{'ispmanVhostScriptDir'}=~m!^/!)?$params->{'ispmanVhostScriptDir'}: join "/", ($homeDirectory, $params->{'ispmanVhostScriptDir'});
        $log_dir=($params->{'ispmanVhostLogdir'}=~m!^/!)?$params->{'ispmanVhostLogdir'}: join "/", ($homeDirectory, $params->{'ispmanVhostLogdir'});
        $stat_dir=($params->{'ispmanVhostStatdir'}=~m!^/!)?$params->{'ispmanVhostStatdir'}: join "/", ($homeDirectory, $params->{'ispmanVhostStatdir'});

        $owner=$params->{'uidNumber'};
        $group=$params->{'gidNumber'};

        push @cmd, "mkdir -p $homeDirectory; chown -R $owner.$group $homeDirectory" unless -d $homeDirectory;
        push @cmd, "mkdir -p $document_root; chown -R $owner.$group $document_root" unless -d $document_root;
        push @cmd, "mkdir -p $script_dir; chown -R $owner.$group $script_dir" unless -d $script_dir;
        push @cmd, "mkdir -p $log_dir; chown -R $owner.$group $log_dir" unless -d $log_dir;
        push @cmd, "mkdir -p $stat_dir; chown -R $owner.$group $stat_dir" unless -d $stat_dir;



}

