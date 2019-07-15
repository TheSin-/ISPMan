package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub controlpanelmenu {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("customerMan/menu.tmpl");
    print $template->fill_in( PACKAGE => "CustomerMan" );
}

sub index {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("customerMan/index.tmpl");
    print $template->fill_in( PACKAGE => "CustomerMan" );
}

1;

__END__

