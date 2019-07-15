
=head1 NAME
ISPMan::Config - Utility functions for accessing values from ispman.conf




=head1 SYNOPSIS

   you don't have to  use this module directly.
   Its used by other ISPMan modules.
   

=head1 DESCRIPTION


This modules loads the ispman.conf file and stores passes the
values to ISPMan.

Some modules are still using ISPMan::Config explicitly which
should be fixed in future.

You may use this module explicitly only if you need values 
from ispman.conf and not any more functionality of ISPMan.

Example if you are writting another program and would rather
that it reads configuration from the ispman.conf instead of 
duplicating the data again.



=head1 METHODS


=over 4

=cut

package ISPMan::Config;

use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config $ConfigDir);

require Exporter;

@ISA     = qw(ISPMan Exporter AutoLoader);
@EXPORT  = qw();
$VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    #my $confDir="/opt/ispman/conf";
    #my $confDir="/opt/ispman/conf";
    my $confDir = $INC{'ISPMan/Config.pm'};
    $confDir =~ s!lib/ISPMan/Config.pm!conf!;
    unless ( -d $confDir ) {

        # look in installdir/tmp/conf #helpful for developers
        $confDir =~ s !conf$!tmp/conf!;
    }

    unless ($Config) {
        unless ( -d $confDir ) {

            # look in /etc
            $confDir = "/etc/ispman/conf";
        }
        die
"\n\nERROR: $confDir does not exists. \nDid you create the configuration directory?\n\n"
          unless ( -e $confDir );
        die "\n\nERROR: $confDir is not a directory\n\n" unless ( -d $confDir );
        die "\n\nERROR: Configuration file $confDir/ispman.conf not found\n\n"
          unless -e "$confDir/ispman.conf";
        defined( do "$confDir/ispman.conf" )
          || die("\n\nERROR reading $confDir/ispman.conf: $@");
        if ( -r "$confDir/nls.conf" ) {
            defined( do "$confDir/nls.conf" )
              || die("\n\nERROR reading $confDir/nls.conf: $@");
        }
        if ( -r "$confDir/custom.conf" ) {
            defined( do "$confDir/custom.conf" )
              || die("\n\nERROR reading $confDir/custom.conf: $@");
        }
    }
    $Config = $ISPMan::Config;
    my $self = $Config;
    return bless $self, $class;

=item B<new>

This method is called only from ISPMan.pm

It does not any more accept an argument.
The configDir is setup on installation.

If configdir is not passed then it looks at the
package global called $ConfigDir, if that is not
set neither then it takes "/opst/ispman/conf" as
the default configuration directory.




I<Example>

  use ISPMan::Config;
  my $conf=ISPMan::Config->new();
  print $conf->{'ldapBaseDN'};



=cut

}

sub getConf {
    my $self = shift;
    my $var  = shift;
    return $self->SUPER::getConf($var);

=item B<getConf>

This method does nothing except calling
SUPER::getConf

Its only here code compatibility.

Once all code is cleaned it will be gone.

See ISPMan.pm's documentation for
  getConfig
  and
  getConf




=cut

}

1;
__END__


=back

=cut

