# derjohn tried it:

sub NotifyUsers_task {
    my ( $domain, $messagefile ) = @_;
    push @cmd, "perl $FindBin::Bin/ispman.notifyUsers -d $domain $messagefile";
    return 1;
}

