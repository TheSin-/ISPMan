package ISPMan::Log;

use strict;

#use Carp;
use ISPMan::Config;
my $Config = ISPMan::Config->new();

$Config->{'logmethod'} = "old"
  if ( !( $Config->{'logmethod'} )
    || ( $Config->{'logmethod'} eq "" )
    || ( $Config->{'logmethod'} eq "file" ) );
$Config->{'logfacility'} = "local5"
  if ( !( $Config->{'logfacility'} ) || ( $Config->{'logfacility'} eq "" ) );

if ( $Config->{'logmethod'} eq "syslog" ) {
    require Sys::Syslog;
    import Sys::Syslog;
}

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config $isLogFileOpen);

require Exporter;

@ISA    = qw(Exporter AutoLoader);
@EXPORT = qw(
  log_event
  syslog_event
);

$VERSION = '0.01';

$|++;

log_event( "called by  " . caller() ) if $Config->{'logmethod'} eq "old";

sub log_event {
    my $self = shift;

    return unless $Config->{'debug'} > 0;
    my $logstring = join( " ", ( caller, @_ ) );

    $logstring = $logstring;
    $logstring =~ s/^ISPMan=.*? //;

    if ( $Config->{'logmethod'} eq "syslog" ) {
        syslog_event( "notice", $logstring );
    }
    else {
        warn($logstring);
    }

}

sub syslog_event {
    return unless $Config->{'debug'} > 0;
    my ( $loglevel, $logstring ) = @_;

    if ( $Config->{'logmethod'} ne "syslog" ) {
        log_event("syslog_event called, but logmethod is not set to syslog");
        log_event("log message was: $logstring");
        return (-1);
    }

    Sys::Syslog::setlogsock( $Config->{'logsock'} || 'inet' );
    openlog( 'ispman', 'cons', $Config->{'logfacility'} );
    syslog( $loglevel, "%s", $logstring );
    closelog();

}

1;

__END__

=head1 NAME

 ISPMan::Log - Perl extension forlogging ISPMan actions to syslog 

     =head1 SYNOPSIS

     use ISPMan::Log;
 log_event ("this will get logged");
syslog_event("warning", "this gets logged to syslog with level WARNING");


=head1 DESCRIPTION

 ISPMan::Log is the logging module forISPMan

     log_event ($message);

 if the ISPMan configuration variable 'logmethod' is set to 'syslog',
 it will log $message to syslog at level 'notice' using the facility
 set by the ISPMan configuration variable 'logfacility', defaulting
 to local5 ifit is not set.
 Defaults to old method if'logmethod' is not set, or has an 
 unrecognized value.  Old method means no logging to apache's error_log.

                 syslog_event ($loglevel,$message);

 Will send $message to syslog using level as specified by $loglevel
 and the facility set by configuration variable 'logfacility'. The
 configuration variable 'logmethod' needs to be set to 'syslog',
 or the the loglevel will be stripped and log_event will be called.

 User should edit /etc/syslog.conf to include a line like:

 <logfacility>.*               /var/log/ispman.log

 or, more finegrained:

 <logfacility>.notice          /var/log/ispman/log.notice
 <logfacility>.crit            /var/log/ispman/log.crit
 <logfacility>.warn            /var/log/ispman/log.warn


 and send a HUP signal to syslog to have it reread its configuration.
 Directories to be logged in must exist, and you may need to create 
 empty logfiles first, depending on the unix flavour ISPMan is running on.

 to in the ISPMan configuration file, usually /etc/ispman/conf/ispman.conf
 the 'logmethod' and 'logfacility' variables must be set:

$Config->{'logmethod'}    = "syslog";
$Config->{'logfacility'}  = "local5";

Logging severity  is controlled by a varaiable called
C<$Config->{'debug'}> that can be defined in ispman.conf

Possible values are between 0 and 3.

0: Be quiet, don't log any thing (for production installations, speeds up the execution a lot)

1: Log user/vhost/domain addition/deletion and other general messages

2: Unclear yet

3: Fill up the damn syslog file. (for debugging when developing, it will slow down the system a lot)


Depends on Sys::Syslog(3)

=head1 AUTHOR

 Armand A. Verstappen <armand@a2vict.nl>

=head1 SEE ALSO

 Sys::Syslog(3), syslog(3)

=head1 TODO

 A bug in certain perl versions caused Sys::Syslog to barf when the 
 logsock was set to 'unix'. The default has now been set to 'inet' as
 a quick fix. This should however be configurable, so as not to force
 the security aware administrator to change the code in order to log 
 to unix sockets in stead of inet sockets.

=cut

  
