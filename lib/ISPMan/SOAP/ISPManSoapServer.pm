package ISPManSoapServer;

my $currDir=$INC{"ISPManSoapServer.pm"};
$currDir=~s!ISPMan/SOAP/ISPManSoapServer.pm!!;
$soap_method_dir="$currDir/ISPMan/SOAP/methods";



unshift @INC, $currDir;
unshift @INC, "../../../";

use ISPMan;
our $ispman=ISPMan->new();


sub AUTOLOAD {
   my $self=shift;
   my $name=$AUTOLOAD;
   $name =~ s/.*://;   # strip fully-qualified portion
   $arguments=join ",", @_;
   $text="You tried to call $name with $arguments\n";
   my $method_name=join "_", ($name, "soap");

   my $soap_method_file="$soap_method_dir/$method_name.pl";

   unless (-d $soap_method_dir){
      $text.="$soap_method_dir does not exists\n";
   }
   unless (-f $soap_method_file){
      $text.="$soap_method_file does not exists\n";
   }
   if (-f $soap_method_file) {
      do $soap_method_file;
      $text=&{$method_name}(@_);
   }
   return $text;
}

__END__


