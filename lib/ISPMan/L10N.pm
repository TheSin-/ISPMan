
=head1 NAME
ISPMan::L10N - routines to translate text.

=cut

package ISPMan::L10N;

use strict;

use ISPMan::Config;
use Locale::Maketext;    # inherits get_handle()

my $languages = {};
my $Config    = ISPMan::Config->new();

my $po;

# set the default;
$languages->{'en_us'} = ['Auto'];
my $localeDir = $Config->{'localeDir'} || $Config->{'installDir'} . "/locale";

for ( keys %{ $Config->{'nls'}{'languages'} } ) {
    $po = "$localeDir/" . $_ . ".po";
    if ( -e $po ) {
        $languages->{$_} = [ "Gettext" => $po ];
    }
    else {
        unless ( $_ eq $Config->{'nls'}{'defaults'}{'language'} ) {
            delete $ISPMan::Config->{'nls'}{'languages'}{$_};
        }
    }
}

use Locale::Maketext::Lexicon;
Locale::Maketext::Lexicon->import($languages);

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter AutoLoader Locale::Maketext);

$VERSION = '0.01';

sub _ {
    my $lh =
      __PACKAGE__->get_handle( $ENV{'LANGUAGE'} )
      ;    # magically gets the current locale
    my $text = join "", @_;
    eval { $text = $lh->maketext(@_) };
    return $text;

}

1;

