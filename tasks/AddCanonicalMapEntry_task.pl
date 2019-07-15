sub AddCanonicalMapEntry_task {
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.add_canonical_map_entry $params->{'domain'} $params->{'ispmanReplicaMaster'}";
}
