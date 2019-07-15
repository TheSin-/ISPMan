sub RemoveRelayDomainEntry_task{
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.remove_relay_domain_entry $params->{'domain'}";
}
