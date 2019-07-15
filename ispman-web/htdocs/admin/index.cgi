#!/usr/bin/perl -w

# FIXME: this shouldn't be a package
package ISPMan;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use CGI;
use CGI::Session qw(-ip-match);
use CGI::Carp qw(fatalsToBrowser);

use strict;

# global vars
our $ispman;
our $r;

# create new CGI object
undef $r;
$r = new CGI;

# check for session cookie
my $sid = $r->cookie("CGISESSID") || $r->param("CGISESSID") || undef;

# get/create session
my $session = new CGI::Session( "driver:File", $sid, { Directory => '/tmp' } );

# get ispman config
require ISPMan::Config;
my $config = ISPMan::Config->new();

if ( $config->{'ispmanUrlPrefix'} ) {
    $ENV{'SCRIPT_NAME'} =
    $config->{'ispmanUrlPrefix'} . "/admin/index.cgi";
}

# do we have a authenticated session?
if ( $session->param("uid") ) {    # yes

    # is this a logout request?
    if ( $r->param("logout") ) {

        # delete session and invalidate cookie
        $session->delete();
        my $cookie = $r->cookie( CGISESSID => "" );

        # redirect to login page
        print $r->redirect(
            -url    => $ENV{'SCRIPT_NAME'},
            -cookie => $cookie
        );
        exit;
    }
}
else {    # no session

    # do we have login credentials?
    if ( $r->param("uid") && $r->param("pass") ) {    # yes, so try logon

        # create LDAP object
        require Net::LDAP;
        my $ldap =
          Net::LDAP->new( $config->{'ldapHost'},
            version => $config->{'ldapVersion'} )
          or die "$@";

        my ( $binddn, $base, $filter, $scope );
        my $uid = $r->param("uid");

        # prepare binddn
        if ( $r->param("logintype") && $r->param("logintype") ne "admin" ) {
            if ( $r->param("logintype") eq "reseller" ) {
                $base   = "ou=ispman,$config->{'ldapBaseDN'}";
                $scope  = "one";
                $filter = "&(objectClass=ispmanReseller)(uid=$uid)";
            }
            if ( $r->param("logintype") eq "client" ) {
                $base   = "ou=ispman,$config->{'ldapBaseDN'}";
                $scope  = "sub";
                $filter = "&(objectClass=ispmanClient)(uid=$uid)";
            }

            # search for binddn
            my $mesg = $ldap->search(
                base    => $base,
                scope   => $scope,
                filter  => "($filter)",
                "attrs" => []
            );
            my ($entry) = $mesg->entry(0);
            unless ($entry) {
                print $r->header();
                print "Entry not found.<br>";

                print "Using base: $base<br>";
                print "Using scope: $scope<br>";
                print "Using filter: $filter<br>";

                exit;
            }

            $binddn = $entry->dn();
        }
        else {    # logintype undef or admin

            $r->param( "logintype", "admin" );
            $binddn = join ',',
              (
                sprintf( "uid=%s", $r->param("uid") ),
                "ou=admins", $config->{'ldapBaseDN'}
              );
        }

        # authenticate to ldap server
        my $result = $ldap->bind( $binddn, password => $r->param("pass") );
        if ( $result->code ) {
            print $r->header();
            print $result->error;
            $ldap->unbind();
        }
        else {    # success

            # save necessary data in session and continue login
            $session->save_param( $r, [ "logintype", "language" ] );
            $session->param( "sessID", time );
            $session->param( "uid",    $uid );
            if ( $binddn =~ /ispmanResellerId=(\d+)/ ) {
                $session->param( "ispmanResellerId", $1 );
            }
            if ( $binddn =~ /ispmanClientId=(\d+)/ ) {
                $session->param( "ispmanClientId", $1 );
            }

            # create session cookie
            my $cookie = $r->cookie( CGISESSID => $session->id );

            # start from the beginning with this new session
            print $r->redirect(
                -url    => $ENV{'SCRIPT_NAME'},
                -cookie => $cookie
            );
        }

        # finished user authentication
        $ldap->unbind();
        exit;
    }
    else {    # no sessions, no credentials

        require ISPMan::L10N;
        require Text::Template;

        # prepare HTML template for login page
        my $templateDirectory = "$config->{'installDir'}/cgi-bin/tmpl";
        my $template          = new Text::Template(
            DELIMITERS => [ '<perl>', '</perl>' ],
            TYPE       => "FILE",
            SOURCE     => "$templateDirectory/login.tmpl"
        );
        print $r->header( -charset => "UTF-8" );
        print $template->fill_in( HASH => $config );
        exit;
    }

}

# NOTICE:
# This point is *only* reached with a valid session id.
# So the user is properly authenticated...

# set new session ID when requested
$session->param( "sessID", time ) if $r->param("newSession");
$session->flush;

print $r->header( -charset => "UTF-8" );

#print "<p>Session Language is ", $session->param("language");
#print "<p>Request Language is ", $r->param("language");

use ISPMan;

$ENV{'LANGUAGE'} = $r->param("language") || $session->param("language");

# create ISPMan object
$ispman = ISPMan->new();

$ispman->remote_user( $session->param("uid") );
$ispman->{'sessID'} = $session->param("sessID");

my $_path = $ENV{'SCRIPT_NAME'};
$_path =~ s!/admin/index.cgi!!;
if (!defined($config->{'ispmanUrlPrefix'})) { $ispman->setConfig( "ispmanUrlPrefix", $_path ); }

my $mode = $r->param("mode");

if ($mode) {
    $ispman->printHeaders() unless $mode =~ /^(ispman|menu|summary|status)$/;
}
else {
    $mode ||= "ispman";
}

# save session in ispman object
$ispman->{'session'} = $session;

# proceed with action
$ispman->$mode($r);

1;

