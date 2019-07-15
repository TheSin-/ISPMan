package ISPMan::MailMan;

use strict;
use Net::SMTP;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  sendmail
);

$VERSION = '0.01';

sub sendmail {
    my $self     = shift;
    my $hash     = shift;
    my $mailhost = $self->getConfig("mailhost") || "localhost";
    my $smtp     = Net::SMTP->new($mailhost);

    $smtp->mail( $hash->{'from'} );
    $smtp->to( $hash->{'to'} );
    $smtp->data();

    $smtp->datasend("To: $hash->{'to'} \n");

    $smtp->datasend("Subject: $hash->{'subject'} \n");
    $smtp->datasend("\n");
    $smtp->datasend( $hash->{'data'} );
    $smtp->dataend();
    $smtp->quit;
}
1;

__END__

