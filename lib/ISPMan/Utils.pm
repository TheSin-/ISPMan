
=head1 NAME
ISPMan::Utils - Utility functions for ISPMan



=head1 SYNOPSIS

   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


These are just some convinience functions.
All are exported to ISPMan.
If you are using ISPMan as in "B<use ISPMan>;",
you can call any of these functions.


=head1 METHODS


=over 4

=cut

package ISPMan::Utils;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  cat
  getTemplate
  refreshSignal
  reloadSignal
  menu
  topmenu
  start
  printHeaders
  ispman
  concatHashRefs
  encryptPass
  encryptPassWithMethod
  explodeDN
  make_fqdn
  overview
  genPass
  status
  staticHost
  as_arrayref
  as_hashref
  as_array
  getAttrVal
  isEmpty
  hasValue
  unique
  substitute
);

$VERSION = '0.01';

sub getTemplate {
    my $self = shift;
    my ($file) = @_;

    my $source;
    my $tmpl_directory;

    if ( $file =~ /^\// ) {
        $source = $file;
    }
    else {
        if ( -d join "/", ( $self->getConf("installDir"), "cgi-bin" ) ) {
            $tmpl_directory = join "/",
              ( $self->getConf("installDir"), "cgi-bin/tmpl" );
        }
        else {

            # ispman-web/cgi-bin (for maintainers)
            $tmpl_directory = join "/",
              ( $self->getConf("installDir"), "ispman-web/cgi-bin/tmpl" );
        }

        $source = join "/", ( $tmpl_directory, $file );
    }

    $self->log_event("opening $source as template")
      if $self->getConfig("debug") > 1;

    my $template = new Text::Template(
        DELIMITERS => [ '<perl>', '</perl>' ],
        TYPE       => "FILE",
        SOURCE     => $source,
    );
    return $template;

=item B<getTemplate>

returns a Text::Template object

accepts filename

if filename does not start with a / then path is relative to cgi-bin directory

The following code is used to create the template
   
   my $template= new Text::Template(
         DELIMITERS => ['<perl>', '</perl>'],
                     TYPE => "FILE",  
                     SOURCE => $source,
   );

Delimiters for template file are "<perl>" and "</perl>"
Please read perldoc Text::Template



I<Example>:

my $ispman=ISPMan->new();

my $template=$ispman->getTemplate("menu.tmpl");

print $template->fill_in();




=cut

}

sub cat {
    my $file = shift;
    return unless $file;
    open "F", $file || die "Cant open $file\n";
    my $text = join "", <F>;
    close("F");
    return $text;

=item B<cat>

accepts filename

returns contents of a file



I<Example>

my $text=$ispman->cat("/etc/passwd");


=cut

}

sub encryptPass {
    my $self = shift;
    my $pass = ( ref($self) ) ? shift: $self;
    unless ( $pass =~ /^{crypt}/ ) {
        $pass = '{crypt}'
          . crypt( $pass, join '',
            ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ] );
    }
    return $pass;
}

sub genPass {
    my $self = shift;
    return join '',
      ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )
      [ rand 64, rand 64, rand 64, rand 64, rand 64, rand 64, rand 64,
      rand 64 ];
}

sub encryptPassWithMethod {
    my $self = shift;
    my ( $pass, $method ) = @_;

    #If password is empty, create a random one.
    $pass ||= $self->genPass();

    unless ( $pass =~ /^{.*}/ ) {
        if ( $method eq 'clear' ) {

            #$pass = '{clear}'.$pass;
        }
        if ( $method eq 'crypt' ) {
            unless ( $pass =~ /^{crypt}/ ) {
                $pass = '{crypt}'
                  . crypt(
                    $pass,
                    join '',
                    ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )
                      [ rand 64, rand 64 ]
                  );
            }
        }
        if ( $method eq 'md5' ) {
            unless ( $pass =~ /^{md5}/ ) {
                require Digest::MD5;
                import Digest::MD5 qw(md5_base64);
                $pass = md5_base64($pass);
                while ( ( length($pass) % 4 ) != 0 ) { $pass .= '='; }
                $pass = '{md5}' . $pass;
            }

        }
        if ( $method eq 'sha' or $method eq 'sha1' ) {
            unless ( $pass =~ /^{sha}/ ) {
                require Digest::SHA1;
                import Digest::SHA1 qw(sha1_base64);
                $pass = sha1_base64($pass);
                while ( ( length($pass) % 4 ) != 0 ) { $pass .= '='; }
                $pass = '{sha}' . $pass;
            }
        }
    }
    return $pass;
}

=item B<refreshSignal>

used by ispman.cgi to refresh the menu if user is added or deleted etc.
sends a javascript reload() function.

=cut

sub explodeDN {
    my $self = shift;
    my $dn   = shift;
    my @attr;
    unless ( ref $self ) {
        $dn = $self;
    }

    if ( $ENV{'HTTP_USER_AGENT'} ) {
        @attr = split( /\s*,\s*/, CGI::unescape($dn) );
    }
    else {
        @attr = split( /\s*,\s*/, $dn );
    }
    my $exploded;

    for (@attr) {
        my ( $var, $val ) = split( /\s*=\s*/, $_ );
        $exploded->{$var} = $val;
    }
    return $exploded;

=item B<explodeDN>

a utility function.

Can be called as a method or a function.


takes a dn as input, and split it by commas and returns a hashref.

I<Example>

my $hash=explodeDN("uid=aghaffar, ou=users, ispmanDomain=developer.ch, o=ispman");

will return 

$hash={
   "uid" => "aghaffar",
   "ou"  => "users",
   "ispmanDomain" => "developer.ch",
   "o"   => "ispman"
   };
   




=cut

}

sub refreshSignal {
    my $self   = shift;
    my $domain = shift;
    return unless $ENV{'HTTP_USER_AGENT'};

    my $params="";

    if ($domain) {
        $params = "&ispmanDomain=$domain";
    }

    return qq|
   <script>
   top.main_menu.location="$ENV{'SCRIPT_NAME'}?mode=menu$params";
   </script>
   |;

=item B<reloadSignal>

used by ispman.cgi to reload the menu-frame if domain is added or deleted etc.
sends a javascript location function.

=cut

}

sub printHeaders {
    my $self     = shift;
    my $template = $self->getTemplate("headers.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<printHeaders>

used by ispman.cgi to send some header text

=cut

}

sub start {
    my $self     = shift;
    my $template = $self->getTemplate("index.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<start>

loads and prints cgi-bin/tmpl/index.tmpl
This is the fist page you see when you visit http://yourserver/cgi-bin/ispman.cgi


=cut

}

sub status {
    my $self     = shift;
    my $template = $self->getTemplate("status.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub overview {
    my $self     = shift;
    my $template = $self->getTemplate("overview.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<overview>

provides overview of the isp.
number of domains, vhosts, users etc.


=cut

}

sub menu {
    my $self     = shift;
    my $template = $self->getTemplate("menu.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
    return;

=item B<menu>

loads and prints right hand side menu for the web interface

cgi-bin/tmpl/menu.tmpl


=cut

}

sub ispman {
    my $self     = shift;
    my $template = $self->getTemplate("ispman.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

=item B<ispman>


Loads and prints the main web interface
frames etc.

=cut

}

sub topmenu {
    my $self     = shift;
    my $template = $self->getTemplate("topmenu.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub concatHashRefs {
    my $self           = shift;
    my $listOfHashrefs = shift;
    my $concatenatedHashref;
    my $key;

    for (@$listOfHashrefs) {
        for $key ( keys %$_ ) {
            $concatenatedHashref->{$key} = $_->{$key};
        }
    }
    return $concatenatedHashref;

=item B<concatHashRefs>


accepts a list of hashrefs
concatenates many hashrefs and returns one.

I<Example>

my $bighash=$ispman->concatHashRefs([$hashef1, $hashref2, $hashref3]);


=cut

}

sub staticHost {
    my $self = shift;
    unless ( ref $self ) {
        unshift @_, $self;
    }
    my ($host) = @_;
    $host =~ s/\.$//g;
    return "$host.";
}

sub make_fqdn {
    my $self = shift;
    unless ( ref $self ) {
        unshift @_, $self;
    }
    my ( $host, $domain ) = @_;

    return $host      if $host =~ /\.$/;    # do nothing. its already static
    return $host      if $host =~ /\*/;     #do nothing if its a *
    return "$domain." if $host =~ /\@/;     #return domain name
    return "$domain." if $host !~ /\S/;    #return domain name if host is blank.
    return "$host.$domain.";               #cat host.domain.
}

sub as_arrayref {
    my $self = shift;
    my @list = $self->as_array(@_);
    return undef unless scalar @list;
    return \@list;

}

sub as_array {

    #take a list of arrays, strings, arrayrefs etc and return as an array

    my $self = shift;
    return undef unless @_;
    my @l = ();
    for (@_) {
        if ( ref $_ eq "ARRAY" ) {
            push @l, @$_;
        }
        else {

            # don't add if $_ is undef
            push @l, $_ if defined($_);
        }
    }
    return @l;
}

sub as_hashref {
    my $self = shift;
    my @list = $self->as_array(@_);
    return {} unless scalar @list;
    my $href = {};
    for (@list) {
        $href->{$_}++;
    }
    return $href;
}

sub getAttrVal {
    my $self = shift;
    my $hash = shift;
    my $attr = shift;
    return ( exists $hash->{$attr} ) ? $hash->{$attr} : $hash->{ lc($attr) };

}

sub hasValue {
    my $self     = shift;
    my $arrayref = shift;
    my $val      = shift;

    my @array = $self->as_array($arrayref);
    for (@array) {
        return 1 if $_ eq $val;
    }
    return 0;
}

sub isEmpty {
    my $self = shift;
    my @vals = $self->as_array(@_);
    for (@vals) {
        return 0 if /\S/;
    }
    return 1;
}

sub unique {

    # return unique elements from a list

    my $self = shift;
    my %hr;
    map { $hr{$_}++ } @_;
    return keys %hr;
}

sub substitute {

    # substitute tokens from substmap in scalar

    my $self = shift;
    my $data = shift;
    my $map  = shift;

    for ( keys %$map ) {
        my $val = $map->{$_};
        $data =~ s/%$_%/$val/g;
    }
    return $data;

=item B<substitute>

substitute tokens with values in supplied data.

I<Example>
my $substmap = {
    item => $var1,
    what => $var2 };

my $var=$ispman->substitute("my %item% is %what%", $substmap);

will result in

$var="my $var1 is $var2";

=cut

}

1;
__END__



=back


=head1 AUTHOR

Atif Ghaffar atif@developer.ch

=head1 SEE ALSO

=cut
