sub RemoveDestinationDomainEntry_task{
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.remove_destination_domain_entry $params->{'domain'}";
}
