sub deleteMailbox_task {
   my $params=shift;
   push @cmd, "perl $FindBin::Bin/ispman.deleteMailbox -h $hostname $params->{'mailbox'}";
}

