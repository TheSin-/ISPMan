package ISPMan::Portal;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  addPortalUser
);
$VERSION = '0.01';

use ISPMan::Config;
$Config = ISPMan::Config->new();

sub addPortalUser {
    my $self = shift;
    my $r    = shift;

    my $userid = $r->param("uid");
    $userid = lc($userid);
    $userid =~ s/[^a-z]//g;
    $r->param( "userid", $userid );

    # lets  crypt the pass
    my $userpassword = $r->param("userpassword");
    if ( $userpassword !~ /^\{crypt\}/ ) {
        $userpassword = '{crypt}'
          . crypt( $userpassword, join '',
            ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ] );
    }
    $r->param( "userpassword", $userpassword );

    my $domain = $r->param("domain");

    #my $_uid=$r->param("uid");
    my $_uid = join '_', ( $r->param("uid"), $r->param("domain") );
    $_uid =~ s/\./_/g;

    $r->param( "uid", $_uid );
    my $dn =
      "uid=$_uid, ou=users, ispmanDomain=$domain, "
      . $self->{'Config'}{'ldapBaseDN'};
    $r->param( "dn",        $dn );
    $r->param( "nsroaming", "N" );

    if ( $self->addUser($r) ) {
        if ( $r->param("maildrophost") ) {
            $self->addProcessToHost( $domain, $r->param("maildrophost"),
                "createPortalUserMailbox", $_uid );
        }
        $self->addProcessToGroup( $domain, "fileservergroup",
            "createPortalUserHomeDirectory", $_uid );
        return 1;
    }
}

1;

__END__

