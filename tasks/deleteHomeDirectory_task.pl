sub deleteHomeDirectory_task {
   my $params=shift;

   # Lets do some checks here for sanity.

   # home Directory Exists?
   unless ($params->{"homeDirectory"}){
      print "Homedirectory not specified\n";
      return 0;
   }
   unless ( -d $params->{"homeDirectory"}){
      print "Homedirectory does not exists\n";
      return 0;
   }

   unless ($params->{"homeDirectory"}=~m!^/[\w.-]+?/[\w.-]+/!){
      print "Home directory too shallow. Too afraid to delete it\n";
      return 0;
   }

   unless ($params->{'uidNumber'} || $params->{'gidNumber'}){
      print "uidNumber and/or gidNumber missing.. Not continuing\n";
      return 0;
   }
   # Do a backup if you have to
   # push  @cmd, "cp -a $params->{"homeDirectory"} /some/backup/dir/";

   # Use this command
   #push @cmd, "find '$params->{"homeDirectory"}' -depth -uid $params->{'uidNumber'} -gid $params->{'gidNumber'} -type d -exec rm -rf {} \\;";

   # Or simply this one
   push @cmd, "rm -rf $params->{'homeDirectory'}";

}


