
=head1 NAME
ISPMan::Handlers - Functions to manage Handlers


=cut

package ISPMan::Handlers;

use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
);
$VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->SUPER::register_handler( "testevent", "testhandler" );
}

1;
__END__

