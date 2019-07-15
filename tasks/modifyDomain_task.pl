sub modifyDomain_task{
	my $params=shift;
	push @cmd, "perl $FindBin::Bin/ispman.make_named_conf $params->{'domain'}";
}


