package CustomerMan;
$|++;
use strict;
use ISPMan;
use ISPMan::GetText;
use CGI::Carp "fatalsToBrowser";
use Mail::RFC822::Address;

require CustomerMan::Utils;              #different utility functions
require CustomerMan::UserMan;            # functions to manage domainusers
require CustomerMan::DNSMan;             # functions to manage DNSEntries
require CustomerMan::ApacheMan;          # functions to manage Vhosts
require CustomerMan::MailGroups;         # functions to manage mailing lists
require CustomerMan::DomainSignature;    # functions to manage mailing lists

use vars
  qw($VERSION @ISA @EXPORT @EXPORT_OK $ldap $imap $Config $ISPMan $TEXTS);

require Exporter;

@ISA     = qw(ISPMan Exporter AutoLoader);
@EXPORT  = qw();
$VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self;
    $ISPMan = ISPMan->new() unless defined $ISPMan;
    $self->{'ispman'} = $ISPMan;
    $self->{'r'}      = $self->{'ispman'}{'r'};

    $self->{'username'} = shift;

    #for testing only
    #$self->{'username'}='test.isp';

    my $baseDN = $self->{'ispman'}->getConf("ldapBaseDN");
    $self->{'Config'}     = $self->{'ispman'}{'Config'};
    $self->{'domain'}     = $self->{'username'};
    $self->{'domaindn'}   = "ispmanDomain=" . $self->{'domain'} . ", $baseDN";
    $self->{'domaininfo'} =
      $self->{'ispman'}->getDomainInfo( $self->{'domain'} );
    $self->{'ldap'} = $ISPMan->{'ldap'};

    $self->{'translator'} = ISPMan::GetText->new();
    $self->{'translator'}->setLocaleDir("/opt/ispman/locale/controlpanel");
    $self->{'translator'}->setLanguage("de");
    return bless $self, $class;
}

sub getText {
    my $self   = shift;
    my $string = shift;
    return $self->{'translator'}->gettext($string);
}

sub manageDomain {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("customerMan/customer.tmpl");
    print $template->fill_in();
}

sub summary {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("customerMan/summary.tmpl");
    print $template->fill_in();
    exit(0);
}

sub advanceItems {
    my $self = shift;
    my $r    = shift;
    my $text = shift;

    my $template = $self->getTemplate("customerMan/advance/advanceHeader.tmpl");
    $text .= $template->fill_in();

    unless ( $r->param("section") ) {

        #$r->param("section", "WebsiteInfos");
    }

    if ( $r->param("section") ) {
        $template =
          $self->getTemplate( join "",
            ( "customerMan/advance/", $r->param("section"), ".tmpl" ) );
        $text .= $template->fill_in()
          || "<font color=red>This module is currently not available</font>";
    }

    $template = $self->getTemplate("customerMan/advance/advanceFooter.tmpl");
    $text .= $template->fill_in();

    print $text;

}

sub getDomainUserQuota {
    my $self       = shift;
    my $domain     = $self->{'domain'};
    my $domainInfo = $self->{'ispman'}->getDomainInfo($domain);
    return $domainInfo->{'ispmanMaxAccounts'};
}

sub addCustomerVhost {
    my $self = shift;
    my $r    = shift;

    my $vhost  = $r->param("ispmanVhostName");
    my $domain = $self->{'domain'};

    my $domainInfo   = $self->{'ispman'}->getDomainInfo($domain);
    my $domainVhosts = $self->getVhostCount($domain);

    my @errors;
    if ( $self->getVhostCount($domain) >= $domainInfo->{'ispmanMaxVhosts'} ) {
        push @errors,
"Vhosts limit exceeded. <br>Your limit is $domainInfo->{'ispmanMaxVhosts'} <br>You cannot create any more Virtualhosts";
    }

    if ( $vhost =~ /[^a-zA-Z0-9\.]/i ) {
        push @errors,
"Illegal website name. You can only use Alphanumerical characters in a website name";
    }

    if (@errors) {
        my $errors =
"This website  was  not created<br><br><br><b>The following errors were encountered</b><br><br>";
        $errors .= join "<br>\n", @errors;
        $r->param( "errors", $errors );
        $self->displayVhosts($r);
        return 0;
    }

    $vhost =~ s/\.$domain//g;

    $r->param( "ispmanVhostName", $vhost );

    my $base = $self->{'ispman'}->getConf("ldapBaseDN");
    my $dn = "ispmanVhostName=$vhost, ou=httpdata, ispmanDomain=$domain, $base";

    $r->param( "ispmanDomain", $domain );
    $r->param( "dn",           $dn );
    $r->param( "ispmanVhostDocumentRootOption",
        [ "Indexes", "FollowSymLinks" ] );
    $r->param( "ispmanVhostScriptDirOption", [ "ExecCGI", "FollowSymLinks" ] );

    my $message = "";
    if ( $self->{'ispman'}->addVhost( $r, 1 ) ) {
        $message .=
"Virtual host $vhost.$domain scheduled for creation<br>It will be activated in a few minutes.<br>";
        $message .=
"Once it is activated you can put files for this domain in the directory /vhosts/$vhost by ftp<br>";

# Atif. 2004/01/13
# This is not any more required as addVhost already takes care of adding the process
# $self->addVhostProcess($r->param("ispmanDomain"), $r->param("cn"), "ModifyVirtualHost", $r->param("cn"));

        $r->param( "message", $message );
        $self->displayVhosts();

    }

}

sub updateWebsiteRedirections {
    my $self                        = shift;
    my $r                           = shift;
    my @ispmanVhostRedirectURL      = $r->param("ispmanVhostRedirectURL");
    my @ispmanVhostRedirectLocation = $r->param("ispmanVhostRedirectLocation");
    for ( 0 .. $#ispmanVhostRedirectURL ) {
        $self->updateRedirect(
            $self->{'domain'}, $r->param("cn"),
            $ispmanVhostRedirectURL[$_],
            $ispmanVhostRedirectLocation[$_]
        );
    }

    $r->param( "mode",    "editVhost" );
    $r->param( "vhost",   $r->param("cn") );
    $r->param( "section", "WebsiteForward" );
    $self->editVhost($r);
}

sub addWebsiteRedirection {
    my $self = shift;
    my $r    = shift;
    if (
        $self->entryExists(
"ispmanVhostName=@{[$r->param('ispmanVhostName')]}, ou=httpdata, $self->{'domaindn'}",
            "ispmanVhostRedirectURL=@{[$r->param('newlocation')]}"
        )
      )
    {
        $r->param( "errors",
            "An Redirection for this location already exists." );
    }
    else {
        $r->param( "ispmanVhostRedirectURL", $r->param("newredirectLocation") );
        $r->param(
            "ispmanVhostRedirectLocation",
            $r->param("newredirectDestination")
        );
        $self->addRedirect($r);
    }
    $r->param( "mode",    "editVhost" );
    $r->param( "vhost",   $r->param("cn") );
    $r->param( "section", "WebsiteForward" );
    $self->editVhost($r);
}

sub updateWebsiteAcl {
    my $self = shift;
    my $r    = shift;
    $self->updateAcl($r);
    $r->param( "mode",    "editVhost" );
    $r->param( "vhost",   $r->param("cn") );
    $r->param( "section", "AccessControl" );
    $r->delete("allow");
    $r->delete("aclid");
    $self->editVhost($r);
}

sub deleteWebsiteAcl {
    my $self = shift;
    my $r    = shift;

    $r->param( "dn",
"ispmanVhostAclLocation=@{[$r->param('ispmanVhostAclLocation')]}, ou=httpAcls, ispmanVhostName=@{[$r->param('vhost')]}, ou=httpdata, $self->{'domaindn'}"
    );
    $r->param( "ispmanDomain", $self->{'domain'} );
    $r->param( "cn",           $r->param("vhost") );

    # NEW method in ApacheMan/Acls.pm  2004/02/01
    $self->delete_acl( $self->{'domain'}, $r->param("vhost"),
        $r->param('ispmanVhostAclLocation') );

    $r->param( "mode",    "editVhost" );
    $r->param( "vhost",   $r->param("cn") );
    $r->param( "section", "AccessControl" );
    $r->delete("allow");
    $r->delete("aclid");
    $self->editVhost($r);

}

sub addWebsiteAcl {
    my $self = shift;
    my $r    = shift;
    if (
        $self->entryExists(
"ispmanVhostName=@{[$r->param('ispmanVhostName')]}, ou=httpdata, $self->{'domaindn'}",
            "ispmanVhostAclLocation=@{[$r->param('newlocation')]}"
        )
      )
    {
        $r->param( "errors", "An ACL for this location already exists." );
    }
    else {
        $r->param( "ispmanVhostAclLocation",  $r->param("newlocation") );
        $r->param( "ispmanVhostAclAllowUser", $r->param("newallow") );
        $self->add_acl($r);
    }
    $r->param( "mode",    "editVhost" );
    $r->param( "vhost",   $r->param("cn") );
    $r->param( "section", "AccessControl" );
    $self->editVhost($r);
}

## User management ##

sub getDomainInfoByAttr {
    my $self       = shift;
    my $attr       = shift;
    my $domain     = $self->{'domain'};
    my $domainInfo = $self->{'ispman'}->getDomainInfo($domain);
    return $domainInfo->{$attr};
}

__END__




