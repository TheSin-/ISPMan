package ISPMan::MessagingMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Email::Valid;

# Atif: 2003-08-08
# derjohn: 2006-07-05: changes and fixes
# Do not load Mail::Internet here
# use it in the send_email_to_domain.lib where it is actually used
# use Mail::Internet;

use POSIX qw(strftime);

require Exporter;

@ISA = qw(ISPMan Exporter AutoLoader);

push @EXPORT, qw(
  notifyUsers
  notifyUsersInDomain
);
$VERSION = '0.01';

# $ispman->notifyUsers() is called from users/notify.tmpl web tyemplate
# Process the form arguments and call notifyUsersInDomain() if all
# parameters are valid.

sub notifyUsers {
    my $self = shift;
    my $r    = shift;

    my $ok  = 1;
    my $err = '';

    my $verifier = new Email::Valid;

    if ( $r->param('fromEmail') ) {
        if (
            !$verifier->address(
                -address => $r->param('fromEmail'),
                -fqdn    => 1
            )
          )
        {
            $err .= 'Invalid e-mail address. ';
            $ok = 0;
        }

        if ( $r->param('cc')
            && !(
                $verifier->address( -address => $r->param('cc'), -fqdn => 1 ) )
          )
        {
            $err .= 'Invalid CC: e-mail address. ';
            $ok = 0;
        }

        if ( !$r->param('subject') ) {
            $err .= 'Message subject must not be empty. ';
            $ok = 0;
        }

        if ( !$r->param('body') ) {
            $err .= 'Message body must not be empty. ';
            $ok = 0;
        }

        if ( !$ok ) {
            $r->param( 'ErrorMessage', $err );
        }
        else {

            # All parameters are correct, let's send the message

            if ( $r->param("notifyDomain") eq "all" ) {
                my $domains = $self->makeDomainHash( $self->getDomains() );
                foreach my $domain ( keys %$domains ) {
                    $self->notifyUsersInDomain( $r, $domain );
                    $r->param( 'cc' => '' );
                }
            }
            else {
                $self->notifyUsersInDomain( $r, $r->param("notifyDomain") );
            }

            my $template =
              $self->getTemplate("users/notificationReadyToSend.tmpl");
            print $template->fill_in( PACKAGE => "ISPMan" );
            return;
        }
    }

    my $template = $self->getTemplate("users/notify.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

# Generates the message header and body in a file and
# creates the agent job 'NotifyUsers'

sub notifyUsersInDomain {
    my $self   = shift;
    my $r      = shift;
    my $domain = shift;

    my $domainInfo = $self->getDomainInfo($domain);

    my $fromAddr = '"';
    if ( ref( $r->{'fromName'} ) ) {
        $fromAddr .= $r->{'fromName'}->[0];
    }
    elsif ( $r->{'fromName'} ) {
        $fromAddr .= $r->{'fromName'};
    }
    else {
        $fromAddr .= $r->{'fromEmail'};
    }
    $fromAddr .= '" <';
    if ( ref( $r->{'fromEmail'} ) ) {
        $fromAddr .= $r->{'fromEmail'}->[0];
    }
    else {
        $fromAddr .= $r->{'fromEmail'};
    }
    $fromAddr .= '>';

    my $msg_dir = $self->getConf("msgSpoolDir");
    $msg_dir ||= '/tmp';

    my $msgfile =
        $msg_dir . '/'
      . strftime( '%Y%m%d%H%M%S', localtime( time() ) )
      . sprintf( "_%s_%.4d.mime", $domain, rand(10000) );

    open( MSGOUT, "> $msgfile" ) or die("Cannot open $msgfile for writing: $!");
    printf MSGOUT ( "From: %s\n",    $fromAddr );
    printf MSGOUT ( "Cc: %s\n",      $r->param('cc') );
    printf MSGOUT ( "Subject: %s\n", $r->param('subject') );
    printf MSGOUT ("MIME-Version: 1.0\n");
    print MSGOUT ("Content-Type: text/plain; charset=\"UTF-8\"\n");
    print MSGOUT ("Content-Disposition: inline\n");
    print MSGOUT ("Content-Transfer-Encoding: 8bit\n");
    print MSGOUT ("\n");
    print MSGOUT ( @{ $r->{'body'} } );
    print MSGOUT ("\n");
    close(MSGOUT);

    $self->addProcessToHost( $domain,
        $domainInfo->{'ispmanDomainDefaultMailDropHost'},
        'NotifyUsers', $msgfile );
}

1;

__END__

