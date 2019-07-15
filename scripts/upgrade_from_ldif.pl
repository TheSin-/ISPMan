#!/usr/bin/perl
die print
"\nUsage: $0 ldif-file\nOh and the file must exists too.\n\nTip: You can create this file by running\nmake ispman\n\n"
  unless ( -e $ARGV[0] );

@path = split( "/", $0 );
pop @path;
$home = join "/", @path, "../";

$ldif = $ARGV[0];

if ( -e "$home/tmp/vars.pl" ) {
    require "$home/tmp/vars.pl";
}
else {
    print
      "Cant find tmp/vars.pl. Make sure that it is in your current directory";
}

$command =
"$home/scripts/subs.pl $ldif | $home/scripts/fixldif.pl | ldapadd -x -c  -h $VAR1->{ldapHost}{default} -D \"$VAR1->{ldapRootDN}{default}\" -w $VAR1->{ldapRootPass}{default} ";

#print "Here is the command that you need to run. I wont run it for you.\nExamine it and run it your self.\n\n$command\n";
print "Running $command\n";
system($command);

exit;
__END__

