sub DeleteVirtualHostDirectories_task{
   my $params=shift;

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

   push @cmd, "rm -rf $params->{'homeDirectory'}";

}

