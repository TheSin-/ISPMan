sub createMailbox_task {
    my $params=shift;

    push @cmd, "perl $FindBin::Bin/ispman.createMailbox -h $hostname $params->{'mailbox'}";
}

