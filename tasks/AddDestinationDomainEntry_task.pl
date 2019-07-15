sub AddDestinationDomainEntry_task{
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.add_destination_domain_entry $params->{'domain'}";
}
