#!/usr/bin/perl
use strict;

BEGIN {

    # see the subroutine at the bottom to figure out the installation location
    locateInstallDir();
    use vars qw($InstallDir);
    unshift @INC, $ISPMan::InstallDir . "/lib";

    use CGI;
    my $cgi = CGI->new();

    #only get in here is a domain cookie is not there
    if ( !$cgi->cookie("domain") || $cgi->cookie("domain") == -1 ) {

        # do we have uid and pass passed

      # "use Module" loads the module  on compile time
      # "require Module" and "import Module" does the same thing as "use Module"
      # but loads an runtime only. So we load if we need.
        require ISPMan::Config;
        import ISPMan::Config;

        # get the config informations in $config
        # we will need the ldapBaseDN and ldapHost values
        my $config = ISPMan::Config->new();

        if ( $cgi->param("domain") && $cgi->param("pass") ) {

            my $dn = "ispmanDomain=";
            $dn .= $cgi->param("domain");
            $dn .= ",$config->{'ldapBaseDN'}";

            require Net::LDAP;
            import Net::LDAP;
            my $ldap =
              Net::LDAP->new( $config->{'ldapHost'},
                version => $config->{'ldapVersion'} )
              or die "$@";
            my $result = $ldap->bind( $dn, password => $cgi->param("pass") );
            if ( $result->code ) {

                # There was an error.
                # Either the domain did not exist
                # or the pass is incorrect
                # complain and exit
                print $cgi->header();
                print $result->error;
                exit;
            }
            else {

                # set the cookie and the session
                my $cookie = $cgi->cookie(
                    -name    => 'domain',
                    -value   => $cgi->param("domain"),
                    -expires => +"1h"
                );
                $cgi->delete("pass");
                $cgi->delete("domain");
                $cgi->param( "mode", "index" );
                print $cgi->redirect(
                    -url    => $cgi->self_url,
                    -cookie => $cookie
                );
            }
        }
        else {
            require ISPMan::L10N;
            import ISPMan::L10N;
            require Text::Template;
            my $templateDirectory;
            if ( -d "$config->{'installDir'}/cgi-bin" ) {
                $templateDirectory = "$config->{'installDir'}/cgi-bin/tmpl";
            }
            else {
                $templateDirectory =
                  "$config->{'installDir'}/ispman-web/cgi-bin/tmpl";
            }
            my $template = new Text::Template(
                DELIMITERS => [ '<perl>', '</perl>' ],
                TYPE       => "FILE",
                SOURCE => "$templateDirectory/customerMan/login.tmpl"
            );
            print $cgi->header();
            print $template->fill_in( HASH => $config );
            exit;
        }
    }

    if ( defined $cgi->param("logout") ) {
        my $cookie =
          $cgi->cookie( -name => 'domain', -value => '-1', -expires => "-1h" );
        print $cgi->redirect( -url => $ENV{'SCRIPT_NAME'}, -cookie => $cookie );
    }

    sub locateInstallDir {
        my @script_components = split '/', $ENV{'SCRIPT_FILENAME'};

        #remove the script name
        pop @script_components;

     #now @script_components contains all the directories from the / in an array

        my $chopDirs = 0;

        if ( -e "../../lib/ISPMan.pm" ) {

            #remove two directories from the end
            $chopDirs = 2;
        }
        elsif ( -e "../../../lib/ISPMan.pm" ) {

            #Developers/maintainers. Without Install
            $chopDirs = 3;
        }
        else {

            #There should be more code here to determine the InstallationPath
            print "Content-type: text/plain\n\n";
            print "Cannot determine Installation Path\n";
            exit;
        }

        if ($chopDirs) {
            for ( 1 .. $chopDirs ) {
                pop @script_components;
            }
        }
        $ISPMan::InstallDir = join '/', @script_components;
        return $ISPMan::InstallDir;
    }

}

package CustomerMan;
use strict;
use CustomerMan;
use CGI;

require CGI::Carp;
import CGI::Carp "fatalsToBrowser";

use vars qw($r $customer $ispman $lang);
undef $r;
$r = new CGI;

$customer = CustomerMan->new( $r->cookie("domain") );
*ispman   = *customer;

if ( $r->param("lang") ) {
    $lang = $r->param("lang");
    my $cookie = $r->cookie( -name => 'lang', -value => $lang, -path => '/' );
    print $r->header( -cookie => $cookie );
    $customer->{'translator'}->setLanguage($lang);
}
else {
    print $r->header;
    if ( $r->cookie("lang") ) {
        $lang = $r->cookie("lang");
    }
    else {
        $lang = 'en';
        $r->param( "lang", $lang );
    }
    $customer->{'translator'}->setLanguage($lang);
}

if ( $r->param("dn") ) {
    my @attr = split( /\s*,\s*/, CGI::unescape( $r->param("dn") ) );
    for (@attr) {
        my ( $var, $val ) = split( /\s*=\s*/, $_ );
        $r->param( $var, $val );
    }
}

$r->param( "domain",       $r->cookie("domain") );
$r->param( "ispmanDomain", $r->cookie("domain") );

my $mode = $r->param("mode");

$mode ||= "summary";

my $_path = $ENV{'SCRIPT_NAME'};
$_path =~ s!/control_panel/index.cgi!!;
$customer->setConfig( "ispmanUrlPrefix", $_path );

$customer->$mode($r);

1;

__END__


