sub RemoveCanonicalMapEntry_task{
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.remove_canonical_map_entry $params->{'domain'}";
}
