
=head1 NAME 

ISPMan - Perl module for ISPMan webAdministrator and command line utils

=head1 SYNOPSIS

  use ISPMan;
  something useful here.

=head1 DESCRIPTION

ISPMan.pm is the top level module which acts as a wrapper to other specialized modules.

As a programmer, you just have to use ISPMan and not other modules directly.

all other modules export their public method in ISPMan's namespace so you call those methods
directly on an ISPMan object.

For example, you can call

&ISPMan::DomainMan->getDomains();

or

simply

$ispman->getDomains();





=cut

package ISPMan;
$|++;
use strict;

use Data::Dumper;
$Data::Dumper::Indent = 2;
use Text::Template;
use ISPMan::L10N;
use ISPMan::LDAP;
use ISPMan::Utils;
use ISPMan::Config;
use ISPMan::UserMan;
use ISPMan::DNSMan;
use ISPMan::DomainMan;
use ISPMan::DomainServices;
use ISPMan::ConfMan;
use ISPMan::ApacheMan;
use ISPMan::ProcessMan;
use ISPMan::HostMan;
use ISPMan::HostGroupMan;
use ISPMan::Log;
use ISPMan::MailMan;
use ISPMan::AdminMan;
use ISPMan::DBMan;
use ISPMan::MailGroupMan;
use ISPMan::ResellerMan;
use ISPMan::ClientMan;
use ISPMan::MessagingMan;
use ISPMan::RadiusMan;

use vars
  qw($VERSION @ISA @EXPORT @EXPORT_OK $ldap $imap $Config $handlers $InstallDir);

require Exporter;

@ISA    = qw(Locale::Maketext Exporter AutoLoader);
@EXPORT = qw(
  explodeDN
);
$VERSION = '0.01';

sub new {

=head1 METHODS

=item B<new>

Returns a new ISPMan instance.

usage

use ISPMan;
$ispman=ISPMan->new();

=cut

    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self;

    unless ($ISPMan::InstallDir) {

        # try to figure out the installation directory;
        $ISPMan::InstallDir = $INC{'ISPMan.pm'};
        $ISPMan::InstallDir =~ s!lib/ISPMan.pm!!;
    }
    my $confDir = $ISPMan::InstallDir . "/conf";    #%REPLACE_THIS_PATH%#
    $Config = ISPMan::Config->new($confDir);
    $self->{'Config'} = $Config;

    if ( $ENV{'HTTP_USER_AGENT'} ) {
        $self->{'REMOTE_USER'} = $ENV{'REMOTE_USER'};
    }
    else {
        $self->{'REMOTE_USER'} = join '@', ( $ENV{'USER'}, $ENV{'HOSTNAME'} );
    }

    $self->{'ldap'} = ISPMan::LDAP->new(
        $Config->{'ldapBaseDN'}, $Config->{'ldapHost'},
        $Config->{'ldapRootDN'}, $Config->{'ldapRootPass'}
    );
    $self->{'ldap'}->setConfig($Config);    #pass config to ISPMan::LDAP
    if ( !$self->{'ldap'}->connected() ) {
        $self->{'ldap'}->connect();
    }

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year += 1900;
    $mon++;
    $mon  = ( $mon < 10 )  ? "0$mon"  : $mon;
    $mday = ( $mday < 10 ) ? "0$mday" : $mday;
    $self->{'year'} = $year;
    $self->{'mon'}  = $mon;
    $self->{'mday'} = $mday;

    if ( defined $Config->{'convert_encoding'}
        && $Config->{'convert_encoding'} )
    {
        require Unicode::String;
        import Unicode::String qw(latin1 utf8 utf16);
    }

    bless $self, $class;
    return $self;

}

sub remote_user {
    my $self = shift;
    my $user = shift;
    if ($user) {
        $self->{'REMOTE_USER'} = $user;
    }
    else {
        return $self->{'REMOTE_USER'};
    }
}

sub dumper {
    my $self = shift;
    return Dumper(@_);
}

sub html_dumper {
    my $self = shift;
    undef $self->{'scratchpad'};
    $self->{'scratchpad'} = "<pre>\n";
    $self->{'scratchpad'} .= Dumper(@_);
    $self->{'scratchpad'} .= "\n</pre>\n";
    return $self->{'scratchpad'};
}

sub getConf {

=item B<getConf>

Returns the value of a configuration variable, either from the
configuration file or from the LDAP directory.

usage

Pass it the name of a configuration variable

Example:

use ISPMan;
$ispman=ISPMan->new();
my $installdir=$ispman->getConf('installDir');

=cut

    my $self = shift;
    my $var  = shift;

    if ( !$Config->{$var} ) {
        $Config->{$var} = $self->{'ldap'}->getConf($var);
    }
    return $Config->{$var};
}

sub getConfig {

=item B<getConfig>

Returns the value of a configuration variable.

usage

Pass it the name of the variable you want to know the value of.

Example:

use ISPMan;
$ispman=ISPMan->new();
$installdir=$ispman->getConfig('installDir');

Note:

This one seems to be reduntant with B<getConf>, I am not sure
which one is prefered

=cut

    my $self = shift;
    my $var  = shift;
    return $self->{'Config'}{$var};
}

sub setConfig {

=item B<setConfig>

Sets the value of the named configuration variable to the specified value.

Example:

use ISPMan;
$ispman=ISPMan->new();
$ispman->setConfig('rootEmail','root@localhost.localdomain');

=cut

    my $self = shift;
    my ( $var, $val ) = @_;
    $self->log_event( "setConfig  called to set $val to  $var by ", caller() )
      if $Config->{'debug'} > 2;
    return $self->{'Config'}{$var} = $val;
}

sub deleteHost {

=item B<deleteHost>

Deletes the host specified by $r->param('hostname') from the
ISPMan hostlist.

usage

Have a cgi-form submit to ispman.cgi, with 'mode' set to 'deleteHost'
and submit a value for hostname.

=cut

    my $self = shift;
    my $r    = shift;
    $self->delete_host( $r->param("hostname") );
}

sub addHostGroup {

=item B<addHostGroup>

Adds a hostgroup to the list of ISPMan hostgroups, using the
values passed in CGI-object $r. A hostgroup is
a way to group ISPMan hosts according to their function.

usage

Have a cgi-form submit to ispman.cgi, setting 'mode' to
'addHostGroup', and submit values for 'cn' and 'description'.

=cut

    my $self = shift;
    my $r    = shift;
    $self->add_host_group( map { $r->param($_) } qw(cn description) );
    $self->manageHostGroups;
}

sub modifyHostGroup {

=item B<modifyHostGroup>

Modify the parameters of a hostgroup using the value provided in
CGI-object $r.

usage

Have a cgi-form submit to ispman.cgi, set 'mode' to 'modifyHostGroup'
and submit values for 'cn', 'description', and optionally an array of
members. The members have to be defined in the ISPMan host list.

=cut

    my $self = shift;
    my $r    = shift;
    $self->modify_host_group(
        $r->param("ispmanHostGroupName"),
        $r->param("ispmanHostGroupInfo"),
        [ $r->param("ispmanHostGroupMember") ]
    );
    $self->manageHostGroups;
}

sub removeHostGroup {

=item B<removeHostGroupp>

Deletes the hostgroup specified by $r->param('ispmanHostGroupName').

usage

Have a cgi-form submit to ispman.cgi, setting mode to 'removeHostGroup'
and 'ispmanHostGroupName' to the name of the host to delete.

=cut

    my $self = shift;
    my $r    = shift;
    $self->deleteHostGroup( $r->param("ispmanHostGroupName") );
    $self->manageHostGroups;
}


sub getRecords {

=item B<getRecords>

Returns the DNS records of type $type for dn $dn

usage

$arecords=$ispman->getRecords($dn, $type);

where type can be one of:

arecords
cnames 
mxrecords 
nsrecords
soarecords

Example

use ISPMan;
use vars qw($ispman);
$ispman=ISPMan->new();
$dn="ispmanDomain=ispman.org, $ispman->{'Config'}{'ldapBaseDN'}";

my $nsrecords=$ispman->getRecords($dn, "nsrecords");

=cut

    my $self = shift;
    my $dn   = shift;
    my $type = shift;

    $dn = ( $dn =~ /^cn\=/ ) ? $dn : "cn=$type, ou=dnsdata, $dn";
    log_event("getRecord $dn");

    unless ( $self->{'dnsdata'}{$dn} ) {
        my $hr;
        $hr = $self->{'ldap'}->getEntriesAsHashRef( $Config->{'ldapBaseDN'},
            "objectclass=domainRelatedObject" );
        for ( keys %$hr ) {
            $self->{'dnsdata'}{$_} = $hr->{$_};

            #print "$_<br>\n";

        }
    }

    return $self->{'dnsdata'}{$dn} if $type eq "soarecords";
    return $self->as_array( $self->{'dnsdata'}{$dn}{'record'} );
}

sub utf2lat {
    my $self = shift;
    return $_[0]
      unless ( defined $self->{'Config'}{'convert_encoding'}
        && $self->{'Config'}{'convert_encoding'} );
    my $string = shift;
    if ( ref $string eq "ARRAY" ) {
        my @newstring = ();
        my $str;
        for $str (@$string) {
            push @newstring, utf8($str)->latin1;
        }
        return \@newstring;
    }
    else {
        return utf8($string)->latin1;
    }
}

sub lat2utf {
    my $self = shift;
    return $_[0]
      unless ( defined $self->{'Config'}{'convert_encoding'}
        && $self->{'Config'}{'convert_encoding'} );
    my $string = shift;
    if ( ref $string eq "ARRAY" ) {
        my @newstring = ();
        my $str;
        for $str (@$string) {
            push @newstring, latin1($str)->utf8;
        }
        return \@newstring;
    }
    else {
        return latin1($string)->utf8;
    }
}

sub xutf2lat {
    my $self = shift;

#return $_[0]  unless (defined $self->{'Config'}{'convert_encoding'} && $self->{'Config'}{'convert_encoding'});
#my $converter=new Text::Iconv $self->{'Config'}{'encoding'}{'utf8'}, $self->{'Config'}{'encoding'}{'local'};
#return $self->convert_encoding($converter, @_);
}

sub xlat2utf {
    my $self = shift;

#return $_[0] unless (defined $self->{'Config'}{'convert_encoding'} && $self->{'Config'}{'convert_encoding'});
#my $converter=new Text::Iconv $self->{'Config'}{'encoding'}{'local'}, $self->{'Config'}{'encoding'}{'utf8'};
#return $self->convert_encoding($converter, @_);
}

sub convert_encoding {
    my $self = shift;
    my ( $converter, $string ) = @_;
    if ( ref $string eq "ARRAY" ) {

        #print "$string Getting ARRAY <br>";
        my @newstring = ();
        my $str;
        for $str (@$string) {
            push @newstring, $converter->convert($str);
        }
        return \@newstring;
    }
    else {

        #print "$string Getting SCALAR <br>";
        return $converter->convert($string);
    }

}

sub DESTROY {

=item B<DESTROY>

FIX ME: Documentation missing.

=cut

    my $self = shift;

    $self->{'ldap'}->{'ldap'} = undef;

}

1;
__END__
=cut

=head1 Examples

B<I<Simple example to fetch all domains from the ldap server.>>


   use ISPMan;
   my $ispman=ISPMan->new();
   my $domains=$ispman->getDomains;
   print join "\n", keys %$domains;

This will print all the domains that are in your LDAP tree.


B<I<Another example to list users from a domain>>

   use ISPMan;
   my $ispman=ISPMan->new();
   my $users=$ispman->getUsers("sourceforge.net");
   print join "\n", keys %$users;



=head1 AUTHOR

Atif Ghaffar, atif@developer.ch

Armand Verstappen, armand@a2vict.nl - Documentation.

=head1 HOMEPAGE

http://ispman.sourceforge.net (source for latest module and more documentation)

or

http://www.ispman.org



=head1 SEE ALSO

perl(1) 
Text::Template(3pm) 
Net::LDAP(3pm)
Net::LDAP::Entry(3pm) 
Net::LDAP::Util(3pm).

=cut


