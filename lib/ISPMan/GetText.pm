
=head1 NAME
ISPMan::GetText - routines to translate text.


=head1 SYNOPSIS

   
=head1 DESCRIPTION


This module is simply a wrapper and does absolutely nothing.

It will go away in future unless it starts doing something useful.



=cut

package ISPMan::GetText;

use strict;
use Data::Dumper;
use vars
  qw($VERSION @ISA @EXPORT @EXPORT_OK $Config $messages $locale_dir $VAR1 $lang);

require Exporter;
@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  setLanguage
  gettext
  settext
  setLocaleDir
);

$VERSION = '0.01';

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub setLocaleDir {
    my $self = shift;
    $locale_dir = shift;
}

sub setLanguage {
    my $self = shift;
    $lang = shift;
    my $file = "$locale_dir/$lang.hash";
    if ( -e $file ) {
        do $file;
        $messages->{$lang} = $VAR1;
    }
}

sub gettext {
    my $self   = shift;
    my $string = shift;

    my $returnString = "";
    if (   $messages->{$lang}{$string}
        && $messages->{$lang}{$string} ne "TranslateMe" )
    {
        $returnString = $messages->{$lang}{$string};
    }
    else {
        $messages->{$lang}{$string} = "TranslateMe";
        $self->settext;
        if ( $lang eq 'en' ) {
            $returnString = $string;
        }
        else {
            $returnString = join '::', ( $lang, $string );
        }
    }
    $returnString =~ s/\n/\\n/g;
    return $returnString;
}

sub settext {
    my $self = shift;
    my $file = "$locale_dir/$lang.hash";
    open "F", ">$file" || die "Cant open file";
    print F Dumper( $messages->{$lang} );
    print F "\n1;\n";
    close("F");
}

1;

