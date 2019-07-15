sub AddRelayDomainEntry_task{
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.add_relay_domain_entry $params->{'domain'} ";
}
