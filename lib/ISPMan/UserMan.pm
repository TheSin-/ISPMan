package ISPMan::UserMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(ISPMan Exporter AutoLoader);
use ISPMan::UserMan::WebUsers;

push @EXPORT, @ISPMan::UserMan::WebUsers::EXPORT;

push @EXPORT, qw(
  create_uid
  newUser
  addUser
  AddUser
  editUser
  suspend_user
  unsuspend_user

  updateUser
  update_user
  deleteUser
  getUsers
  createUser
  cantAddUsersToReplicaDomain
  getUserInfo
  killUser
  getUserCount
  getUsersCount
  userExists
  getUsersBranchDN
  getUserDN
  fixDuplicateUsers
  getMailAliasesForUser
  addMailAliasForUser
  replaceMailAliasForUser
  getMailForwardsForUser
  addMailForwardForUser
  replaceMailForwardForUser

  set_user_attributes
  getUserAttributeValues
  addUserAttributeValues
  replaceUserAttributeValues

  changePassword
  searchUsers

  addUserFileServerProcess
  containsInvalidMailAliases
  getDNForMailAddress
);

$VERSION = '0.01';

sub cantAddUsersToReplicaDomain {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param("ispmanDomain");
    print "Sorry cannot add users to a replica domain<br>"
      . "Instead add users to its master domain which is ";

    my $replicaMaster =
      $self->getEntry(
        "ispmanDomain=$domain, $self->{'Config'}->{'ldapBaseDN'}",
        , ["ispmanReplicaMaster"] )->get_value("ispmanReplicaMaster");
    print "<h1>$replicaMaster</h1>";

}

sub createUser {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");

    my $domaintype = $self->getDomainType( $r->param("ispmanDomain") );

    return $self->cantAddUsersToReplicaDomain($r)
      if lc($domaintype) eq "replica";
    my $template;
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("users/add.tmpl");
    }
    else {
        $template = $self->getTemplate("ro.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub newUser {
    my $self = shift;
    my $r    = shift;
    if ( $self->addUser($r) ) {
        print $self->refreshSignal( $r->param("ispmanDomain") );
        $self->editUser($r);
    }
}

sub AddUser {
    &goto("addUser");
}

sub addUser {
    my $self = shift;
    my $r    = shift;

    # filter supplied uid
    my $userid = $r->param("uid");
    $userid = lc($userid);
    $userid =~ s/[^a-z0-9\-_\.]//g;
    $r->param( "userid", $userid );

    # lets  crypt the pass
    my $userpassword = $self->encryptPassWithMethod( $r->param("userPassword"),
        $self->getConf('userPassHashMethod') );
    $r->param( "userPassword", $userpassword );

    my $domain = $r->param("ispmanDomain");

    # check user limit for this domain
    my $domainMaxUsers =
      $self->getDomainAttribute( $domain, "ispmanMaxAccounts" );
    my $domainUserCount = $self->getUserCount($domain);
    if ( $domainMaxUsers > 0 && $domainUserCount >= $domainMaxUsers ) {
        $self->{'message'} =
            "Max accounts limit exceeded. <br>"
          . "Your limit is $domainMaxUsers <br>"
          . "You cannot create any more users.";
        print $self->{'message'};
        return;
    }

    # build unique uid from userid and domain
    my $_uid =
      $self->create_uid( $r->param("userid"), $r->param("ispmanDomain") );
    $r->param( "uid", $_uid );

    # check uid conflicts with existing mail addresses
    if (
        my $check = $self->getDNForMailAddress(
            join '@', ( $r->param("userid"), $r->param("ispmanDomain") )
        )
      )
    {
        print "Unable to create user \"$_uid\", because mail address is<br>"
          . "already blocked by \"$check\".";
        return;
    }

    # build new DN for user
    my $dn =
      "uid=$_uid, ou=users, ispmanDomain=$domain, "
      . $self->{'Config'}{'ldapBaseDN'};
    $r->param( "dn", $dn );

    $self->prepareBranchForDN(
        "ou=users, ispmanDomain=$domain, @{[$self->getConf('ldapBaseDN')]}");

    # get domain info and supply it to session data
    # so we can use it in user ldif template
    my $domain_info = $self->getDomainInfo( $r->param("ispmanDomain") );
    $r->param( "domaininfo", $domain_info );

    # validate ftp quota
    if (   $r->param("FTPQuotaMBytes") !~ /\d\d*/
        || $r->param("FTPQuotaMBytes") < 0 )
    {
        $r->param( "FTPQuotaMBytes", $self->getConf('defaultUserFtpQuota') );
    }

    # validate mail quota
    if ( $r->param("mailQuota") !~ /\d\d*/ || $r->param("mailQuota") < 0 ) {
        $r->param( "mailQuota", $self->getConf('defaultUserMailQuota') );
    }

    unless ( defined $r->param("fileHost") && $r->param("fileHost") ne "none" )
    {
        $r->param( 'fileHost', $self->getDefaultFileHost($domain) );
    }

    # add user to LDAP from user ldif template
    if ( $self->addDataFromLdif( "templates/users.ldif.template", $r ) ) {

        # reread user from LDAP to get computed values
        my $_userInfo = $self->getUserInfo($_uid);

        if ( $r->param("mailHost") ) {
            my $quota = $r->param("mailQuota") * 1024;
            $self->addProcessToHost( $domain, $_userInfo->{'mailHost'},
                "createMailbox",
                "mailbox=" . $_userInfo->{'mailLocalAddress'} );

            $self->addProcessToHost(
                $domain,
                $_userInfo->{'mailHost'},
                "setMailboxQuota",
                "mailbox="
                  . $_userInfo->{'mailLocalAddress'} . "&"
                  . "quota=$quota"
            );
        }

        # send the process to method addUserFileServerProcess
        # the process will only be sent to fileHost if one is defined
        # if not defined then we fall back to the old method and
        # send to the filserver group

        # passing domain, username, process and username as params
        $self->addUserFileServerProcess( $domain, $_uid, 'createHomeDirectory',
                "uid=$_uid&homeDirectory=$_userInfo->{'homeDirectory'}&"
              . "uidNumber=$_userInfo->{'uidNumber'}&"
              . "gidNumber=$_userInfo->{'gidNumber'}" );
        return 1;
    }

}

sub getDNForMailAddress {
    my $self  = shift;
    my $found = "";
    while ( !$found && ( my $mail = shift ) ) {
        my $entries =
          $self->getEntriesAsHashRef( $self->{'Config'}->{'ldapBaseDN'},
            "|(mailLocalAddress=$mail)(mailAlias=$mail)" );
        ($found) = keys %$entries;
    }
    return $found;
}

sub getUserInfo {
    my $self = shift;
    my $uid  = shift;
    my $_hr  =
      $self->getEntriesAsHashRef( $self->{'Config'}->{'ldapBaseDN'},
        "uid=$uid" );
    my ($key) = keys %{$_hr};
    $self->{'userinfo'}{$uid} = $_hr->{$key};
    return $self->{'userinfo'}{$uid};
}

sub editUser {
    my $self = shift;
    my $r    = shift;

    my $dn = $self->getUserDN( $r->param("ispmanDomain"), $r->param("uid") );

    $self->{'user'} = $self->getEntryAsHashRef($dn);
    $self->{'user'}{'dn'} = $dn;

    my $template;
    if ( $self->isDomainEditable( $r->param("ispmanDomain") ) ) {
        $template = $self->getTemplate("users/edit.tmpl");
    }
    else {
        $template = $self->getTemplate("users/view.tmpl");
    }
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub killUser {
    my $self = shift;
    my $dn   = shift;

    #bare function to remove user,
    #can be called from CLI or other subroutines
    # get all values from the dn to the hash

    print "Deleting $dn<br>";
    $self->{'user'} = $self->{'ldap'}->getEntryAsHashRef($dn);

    #it is possible that as user has multiple uids.
    #hint
    #aghaffar_ispman_org
    #aghaffar@ispman.org
    if ( ref $self->{'user'}{'uid'} eq "ARRAY" ) {
        $self->{'user'}{'uid'} = $self->{'user'}{'uid'}[0];
    }

    # first send processes.

    # %%% new method %%
    # send the process to method addUserFileServerProcess
    # the process will only be sent to fileHost if one is defined
    # if not defined then we fall back to the old method and
    # send to the filserver group

    $self->addUserFileServerProcess(
        $self->{'user'}{'ispmanDomain'},
        $self->{'user'}{'uid'},
        'deleteHomeDirectory',
        join '&',
        (
            "uid=" . $self->{'user'}{'uid'},
            "homeDirectory=" . $self->{'user'}{'homeDirectory'},
            "uidNumber=" . $self->{'user'}{'uidNumber'},
            "gidNumber=" . $self->{'user'}{'gidNumber'}
        )
    );

    if ( $self->{'user'}{"mailHost"} ) {
        $self->addProcessToHost(
            $self->{'user'}{'ispmanDomain'},
            $self->{'user'}{"mailHost"},
            "deleteMailbox", "mailbox=" . $self->{'user'}{'mailLocalAddress'}
        );
    }

    $self->deleteEntry($dn);

    # Delete User PAB
    my $pab_dn = 'ou='
      . $self->{'user'}{'uid'} . ',ou='
      . $self->{'user'}{'ispmanDomain'}
      . ',ou=pabs,'
      . $self->getConf("ldapBaseDN");
    print "deleting PAB: $pab_dn";
    $self->delTree($pab_dn);
}

sub deleteUser {
    my $self = shift;
    my $r    = shift;

    my $dn = $self->getUserDN( $r->param("ispmanDomain"), $r->param("uid") );

    $self->killUser($dn);

    print $self->refreshSignal( $r->param("ispmanDomain") );

    # This message should be sent via some message template
    print "User deleted";
}

sub updateUser {
    my $self = shift;
    my $r    = shift;
    if ( $self->update_user($r) ) {
        print $self->refreshSignal( $r->param("ispmanDomain") );
        $self->editUser($r);
    }
}

# added by Michael Bunk, Jan 2006
sub containsInvalidMailAliases {
    my $self         = shift;
    my $user         = shift;
    my $masterDomain = shift;
    my $aliases      = shift;
    my $replicas     = $self->getReplicasOfDomain($masterDomain);
    my @validDomains;

    # determine all valid domains
    if ( defined($replicas) ) { @validDomains = keys %$replicas; }
    push @validDomains, $masterDomain;

    # check all aliases for validity
    foreach (@$aliases) {
        next if /^$/;

        # check fully qualified address
        if (/^[\w\.\-\+]+$/) {
            return ( 1, _("Mail address is not fully qualified") . ": " . $_ );
        }

        if ( lc( $self->getConf("allowCrossDomainAliases") eq "no" ) ) {

            # check for out-of-bounds addresses
            if (/^[\w\.\-\+]*@([\w\.\-]+)$/) {
                if ( !grep /^$1$/, @validDomains ) {
                    return (
                        1,
                        _(
                            "Mail aliases to users from foreign domains are forbidden"
                          )
                          . ": "
                          . $_
                    );
                }
            }
        }

        # check for uniqueness
        my $found_dn = $self->getDNForMailAddress($_);
        $found_dn =~ s/ //g;
        my $user_dn = $self->getUserDN( $masterDomain, $user );
        if ( defined($found_dn) && ( $found_dn ne $user_dn ) ) {
            return ( 1,
                    _("Mail alias") . " " . $_ . " "
                  . _("conflicts with") . "\""
                  . $found_dn
                  . "\".<br>"
                  . _("Aborting update!") );
        }
    }

    return ( 0, undef );
}

sub update_user {
    my $self = shift;
    my $r    = shift;
    my $dn   = $self->getUserDN( $r->param("ispmanDomain"), $r->param("uid") );
    my $userInfo = $self->getUserInfo( $r->param("uid") );
    my $data     = {};
    for (
        qw(sn givenName homeDirectory loginShell mailLocalAddress mailRoutingAddress FTPStatus FTPQuotaMBytes)
      )
    {
        $data->{$_} = $r->param($_) if defined $r->param($_);
    }

    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $r->param("userPassword"),
        $self->getConf('userPassHashMethod') );
    $data->{'cn'} = join ' ', ( $r->param("givenName"), $r->param("sn") );

    $data->{'mailAlias'} =
      $self->as_arrayref( split( /\s+/, $r->param("mailAlias") ) );

    # check mail aliases
    my ( $invalid, $errmsg ) =
      $self->containsInvalidMailAliases( $r->param("uid"),
        $userInfo->{'ispmanDomain'},
        $data->{'mailAlias'} );
    if ($invalid) {
        print $errmsg;
        return 0;
    }

    $data->{'mailForwardingAddress'} =
      $self->as_arrayref( split( /\s+/, $r->param("mailForwardingAddress") ) );

    # don't set objectclasses here! It would dishonor non-ispman
    # objectclasses and attributes. Update issues are handled by
    # ldifupdate anyways.
    # $data->{'objectClass'} = $self->{'Config'}{'ispmanUserObjectclasses'};

    if ( $userInfo->{'mailHost'} && $r->param("mailQuota") ) {
        my $quota   = $r->param("mailQuota") * 1024;
        my $mailbox = $r->param("mailLocalAddress");
        unless ( $quota == $userInfo->{'mailQuota'} ) {
            $data->{'mailQuota'} = $quota;
            $self->addProcessToHost(
                $userInfo->{'ispmanDomain'}, $userInfo->{'mailHost'},
                "setMailboxQuota",           "mailbox=$mailbox&quota=$quota"
            );
        }
    }

    $self->updateEntryWithData( $dn, $data );
    return 1;

}

sub set_user_attributes {

    # get domain, uid and a hash and set the key=value
    # of $data to user record
    my $self = shift;
    my ( $domain, $uid, $data ) = @_;

    my $dn = $self->getUserDN( $domain, $uid );
    $self->updateEntryWithData( $dn, $data );
}

sub changePassword {
    my $self = shift;
    my ( $uid, $domain, $pass, $method ) = @_;
    my $dn = $self->getUserDN( $domain, $uid );
    my $data = {};
    $data->{'userPassword'} = $self->encryptPassWithMethod( $pass, $method );
    $self->updateEntryWithData( $dn, $data );
}

sub addMailAliasForUser {
    my $self = shift;
    my ( $uid, $domain, $values ) = @_;

    # added by Michael Bunk, Jan 2006
    my ( $invalid, $errmsg ) =
      $self->containsInvalidMailAliases( $uid, $domain, $values );
    if ($invalid) {
        print $errmsg;

        # actually, we should return a Net::LDAP::Message to return the same
        # type as addUserAttributeValues()
        return 0;
    }

    return $self->addUserAttributeValues( $uid, $domain, 'mailAlias', $values );
}

sub replaceMailAliasForUser {
    my $self = shift;
    my ( $uid, $domain, $values ) = @_;

    # added by Michael Bunk, Jan 2006
    my ( $invalid, $errmsg ) =
      $self->containsInvalidMailAliases( $uid, $domain, $values );
    if ($invalid) {
        print $errmsg;

        # actually, we should return a Net::LDAP::Message to return the same
        # type as addUserAttributeValues()
        return 0;
    }

    return $self->replaceUserAttributeValues( $uid, $domain, 'mailAlias',
        $values );
}

sub getMailAliasesForUser {
    my $self = shift;
    my ( $uid, $domain ) = @_;
    return $self->getUserAttributeValues( $uid, $domain, 'mailAlias' );
}

sub addMailForwardForUser {
    my $self = shift;
    my ( $uid, $domain, $values ) = @_;
    return $self->addUserAttributeValues( $uid, $domain,
        'mailForwardingAddress', $values );
}

sub replaceMailForwardForUser {
    my $self = shift;
    my ( $uid, $domain, $values ) = @_;
    return $self->replaceUserAttributeValues( $uid, $domain,
        'mailForwardingAddress', $values );
}

sub getMailForwardsForUser {
    my $self = shift;
    my ( $uid, $domain ) = @_;
    return $self->getUserAttributeValues( $uid, $domain,
        'mailForwardingAddress' );
}

sub getUsersCount {
    my ($self) = @_;
    return $self->getCount( $self->getConf('ldapBaseDN'),
        "&(objectclass=ispmanDomainUser)", ["uid"] );
}

sub getUserCount {
    my $self   = shift;
    my $domain = shift;
    my $base   = "ou=users,ispmanDomain=$domain, ";
    $base .= $self->getConf("ldapBaseDN");

    return $self->getCount( $base, "&(objectClass=ispmanDomainUser)", ["uid"] );
}

sub getUsersBranchDN {
    my $self   = shift;
    my $domain = shift;
    return
      join( ",", "ou=users,ispmanDomain=$domain",
        $self->getConf('ldapBaseDN') );
}

sub getUserDN {
    my $self = shift;
    my ( $domain, $uid ) = @_;
    $uid =~ s/\.|\@/_/g;
    return join( ",", "uid=$uid", $self->getUsersBranchDN($domain) );
}

sub getUsers {
    my $self   = shift;
    my $domain = shift;
    my $attr   = shift || [ "cn", "uid" ];
    my $branch = $self->getUsersBranchDN($domain);
    my $users  =
      $self->getEntriesAsHashRef( $branch, "objectclass=ispmanDomainUser",
        $attr );
    return $users;

    #return $self->fixDuplicateUsers($users);
}

# FIXME:
# This is a method for presentation layer (circumventing it for now)
sub fixDuplicateUsers {
    my $self     = shift;
    my $userhash = shift;
    my $user;
    my $cn;
    my $cnHash;
    for ( keys %$userhash ) {
        if ( $userhash->{$_}{'cn'} ) {
            $cn = $userhash->{$_}{'cn'};
            $cnHash->{$cn}++;
            $cn .= "(@{[$cnHash->{$cn}]})" if $cnHash->{$cn} > 1;
            $user->{$cn} = $_;
        }
        else {
            $user->{ $userhash->{$_}{'uid'} } = $_;
        }
    }
    return $user;
}

sub searchUsers {
    my $self     = shift;
    my $template = $self->getTemplate("users/search.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub userExists {
    my $self = shift;
    my $uid  = shift;
    return $self->getCount( $self->getConf('ldapBaseDN'), "uid=$uid" );
}

sub suspend_user {
    my $self = shift;

    my ( $domain, $uid ) = @_;
    my $dn = $self->getUserDN( $domain, $uid );
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'disabled', 'ispmanStatus' => "suspended" } );
    return;
}

sub unsuspend_user {
    my $self = shift;
    my ( $domain, $uid ) = @_;
    my $dn = $self->getUserDN( $domain, $uid );
    $self->updateEntryWithData( $dn,
        { 'FTPStatus' => 'enabled', 'ispmanStatus' => "active" } );
    return;
}

sub replaceUserAttributeValues {
    my $self = shift;
    my ( $uid, $domain, $attribute, $values ) = @_;
    $self->updateEntryWithData( $self->getUserDN( $domain, $uid ),
        { $attribute => $values } );
}

sub getUserAttributeValues {
    my $self = shift;
    my ( $uid, $domain, $attribute ) = @_;
    print "Returning $attribute for $uid\@$domain\n";

    $self->getUserInfo($uid);
    return $self->{'userinfo'}{$uid}{$attribute};
}

sub addUserAttributeValues {
    my $self = shift;
    my ( $uid, $domain, $attribute, $values ) = @_;
    my $_values =
      $self->as_arrayref(
        $self->getUserAttributeValues( $uid, $domain, $attribute ), $values );
    $self->updateEntryWithData( $self->getUserDN( $domain, $uid ),
        { $attribute => $_values } );
}

# generate unique uid from userid and domain
sub create_uid {
    my $self = shift;
    my ( $userId, $domain ) = @_;

    $domain =~ s/\./_/g;
    $userId =~ s/\./_/g;

    unless ( $userId =~ /$domain$/ ) {
        $userId = join "_", ( $userId, $domain );
    }
    return $userId;
}

sub addUserFileServerProcess {

    # What happens on file server?
    # create home directory
    # delete home direcory
    my $self = shift;
    my ( $domain, $uid, $process, $param ) = @_;
    my $userInfo = $self->getUserInfo($uid);
    if ( $userInfo->{'fileHost'} ) {
        return if $userInfo->{'fileHost'} eq "undefined";
        $self->addProcessToHost( $domain, $userInfo->{'fileHost'},
            $process, $param );
    }
    else {
        $self->addProcessToGroup( $domain, 'fileservergroup', $process,
            $param );
    }
}

1;

__END__

