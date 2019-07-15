package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub addDomainUser {
    my $self   = shift;
    my $domain = $self->{'domain'};
    print "Adding user in domain $domain<br>";
    my $template = $self->getTemplate("customerMan/users/addDomainUser.tmpl");
    print $template->fill_in( PACKAGE => "CustomerMan" );
}

sub newDomainUser {
    my $self   = shift;
    my $domain = $self->{'domain'};

    #print "Domain: $domain <br>";

    my $r = shift;

    #print $r->as_string;

    my $domainInfo = $self->{'ispman'}->getDomainInfo($domain);

    #print $self->html_dumper($domainInfo);

    my $domainUsers = $self->getUserCount($domain);

    #print $self->html_dumper($domainUsers);

    my @errors = ();

    if (   $domainInfo->{'ispmanMaxAccounts'} > 0
        && $domainUsers >= $domainInfo->{'ispmanMaxAccounts'} )
    {
        push @errors,
"Accounts limit exceeded. <br>Your Accounts limit is $domainInfo->{'ispmanMaxAccounts'}<br> You cannot create any more accounts";
    }

    unless ( $r->param("ispmanUserId") ) {
        push @errors, "Username not defined";
    }
    unless ( $r->param("givenName") ) {
        push @errors, "Firstname not defined";
    }
    unless ( $r->param("sn") ) {
        push @errors, "Lastname not defined";
    }
    unless ( $r->param("userPassword") ) {
        push @errors, "Password not defined";
    }

    if (@errors) {
        my $errors =
"User was  not created<br><br><br><b>The following errors were encountered</b><br><br>";
        $errors .= join "<br>\n", @errors;
        $r->param( "errors", $errors );
        $self->addDomainUser();
        return 0;
    }

    $domainInfo = $self->{'ispman'}->getDomainInfo($domain);

    my $givenname    = $r->param("givenName");
    my $sn           = $r->param("sn");
    my $userpassword = $r->param("userPassword");
    my $username     = $r->param("ispmanUserId");

    $givenname =~ s/^\s\s*//g;
    $givenname =~ s/\s\s*$//g;

    $sn =~ s/^\s\s*//g;
    $sn =~ s/\s\s*$//g;

    $userpassword =~ s/^\s\s*//g;
    $userpassword =~ s/\s\s*$//g;

    $username =~ s/^\s\s*//g;
    $username =~ s/\s\s*$//g;

    if ( $self->userExists($username) ) {
        print "User account already exists.";
        return;
    }

    $r->param( "uid",      $username );
    $r->param( "mailHost", $domainInfo->{'ispmanDomainDefaultMailDropHost'} );
    $r->param( "ispmanDomain", $self->{'domain'} );

    my $infoHash;

    #if ($self->{'ispman'}->addUser($r)){
    if ( $self->{'ispman'}->addUser($r) ) {
        my $infoHash;
        $infoHash->{'username'}     = $username;
        $infoHash->{'uid'}          = $self->userid2uid($username);
        $infoHash->{'userpassword'} = $userpassword;
        $infoHash->{'domain'}       = $domain;
        $infoHash->{'givenname'}    = $givenname;
        $infoHash->{'sn'}           = $sn;
        my $message = qq|
         User created<br><br>
         Please print out the following information about the user<br><hr>
      |;
        $infoHash->{'message'} = $message;
        $r->param( "message", $message );

        my $template =
          $self->getTemplate("customerMan/users/showDomainUserInfo.tmpl");
        print $template->fill_in( HASH => $infoHash );
    }
}

sub deleteDomainUser {
    my $self = shift;
    my $r    = shift;

    my $domain = $self->{'domain'};
    my $uid    = $self->userid2uid( $r->param("user") );
    my $dn     = "uid=$uid, ou=users, $self->{'domaindn'}";
    $self->{'ispman'}->killUser($dn);
    $r->param( "mode",    "editDomainUser" );
    $r->param( "message", $self->getText("User deleted") );
    $r->delete("user");
    $self->editDomainUser($r);

}

sub editDomainUser {
    my $self = shift;
    my $r    = shift;
    unless ( $r->param("user") ) {
        $r->param( "section", "" );
        my $template =
          $self->getTemplate("customerMan/users/editDomainUserHeader.tmpl");
        print $template->fill_in();
        return;
    }

    $self->{'user'} =
      $self->{'ispman'}->getUserInfo(
        $self->{'ispman'}->create_uid( $r->param("user"), $self->{'domain'} ) );

    my $text = "";

    unless ( $r->param("section") ) {
        $r->param( "section", "PersonalInfo" );
    }
    my $template =
      $self->getTemplate("customerMan/users/editDomainUserHeader.tmpl");
    $text .= $template->fill_in();

    $template =
      $self->getTemplate( join "",
        ( "customerMan/users/editDomainUser", $r->param("section"), ".tmpl" ) );
    $text .= $template->fill_in();

    $template =
      $self->getTemplate("customerMan/users/editDomainUserFooter.tmpl");
    $text .= $template->fill_in();

    print $text;
}

sub manageDomainUsers {
    my $self     = shift;
    my $r        = shift;
    my $template =
      $self->getTemplate("customerMan/users/manageDomainUsers.tmpl");
    print $template->fill_in();
}

sub getDomainUsers {
    my $self = shift;

    my $_dn;
    my $_users;

    return $self->{'ispman'}->getUsers( $self->{'domain'} );
}

sub editUsers {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("customerMan/users/editUsers.tmpl");
    print $template->fill_in();
}

sub changeDomainUserPersonalInfo {
    my $self = shift;
    my $r    = shift;
    $self->{'ispman'}->set_user_attributes(
        $self->{'domain'},
        $self->{'ispman'}->create_uid( $r->param("user"), $self->{'domain'} ),
        {
            'givenName' => $r->param("givenName"),
            'sn'        => $r->param("sn"),
            'cn'        => $r->param("cn")
        }
    );

    $r->param( "mode",    "editDomainUser" );
    $r->param( "section", "PersonalInfo" );
    $self->editDomainUser($r);
}

sub changeDomainUserPass {
    my $self = shift;
    my $r    = shift;

    my $uid = $self->userid2uid( $r->param("user") );
    $self->{'ispman'}
      ->changePassword( $uid, $self->{'domain'}, $r->param("pass"),
        $self->{'ispman'}->getConf('userPassHashMethod') );
    $r->param( "message",
"Password changed to <font size=+1 color=maroon>@{[$r->param('pass')]}</font> for <font size=+1 color=maroon>$uid</font>"
    );
    $r->param( "mode", "editDomainUser" );
    $self->editDomainUser($r);

}

sub addMailAlias {
    my $self = shift;
    my $r    = shift;
    my ( $mail, $dom ) = split( '@', $r->param("alias") );
    my $alias = join '@', ( $mail, $self->{'domain'} );
    my $uid   = $self->userid2uid( $r->param("user") );

    $self->{'ispman'}->addMailAliasForUser( $uid, $self->{'domain'}, $alias );

    $r->param( "mode",    "editDomainUser" );
    $r->param( "section", "EmailAliases" );
    $self->editDomainUser($r);
}

sub deleteMailAlias {
    my $self = shift;
    my $r    = shift;

    if ( $r->param("mailAlias") ) {
        my $uid         = $self->userid2uid( $r->param("user") );
        my $aliasHash   = {};
        my $mailAliases =
          $self->as_arrayref(
            $self->{'ispman'}->getMailAliasesForUser( $uid, $self->{'domain'} )
          );

        #print $self->html_dumper($mailAliases);

        if ($mailAliases) {

            #fill up the hash with all mailAliases.
            for (@$mailAliases) {
                $aliasHash->{$_}++;
            }

            #now delete the ones that we are being passed.
            for ( $r->param("mailAlias") ) {
                delete $aliasHash->{$_};
            }

          #call replaceMailAliasForUser method with reference to list of aliases
            $self->replaceMailAliasForUser( $uid, $self->{'domain'},
                [ keys %$aliasHash ] );
        }
    }

    $r->param( "mode",    "editDomainUser" );
    $r->param( "section", "EmailAliases" );
    $self->editDomainUser($r);

}

sub addMailDrop {
    my $self     = shift;
    my $r        = shift;
    my $maildrop = $r->param("maildrop");
    my @errors   = ();
    if ( Mail::RFC822::Address::valid($maildrop) ) {
        my $uid = $self->userid2uid( $r->param("user") );
        my $dn  = "uid=$uid, ou=users, $self->{'domaindn'}";
        if ( $self->{'ispman'}
            ->getCount( $dn, "mailForwardingAddress=$maildrop" ) )
        {
            $r->param( "message", "Mail drop $maildrop  exists for  $uid" );
        }
        else {
            $r->param( "message", "Adding $maildrop  for $uid" );
            $self->{'ispman'}
              ->addData2Entry( $dn, { "mailForwardingAddress" => $maildrop } );
        }
    }
    else {
        $r->param( "error",
            "Address $maildrop is not a valid internet email addres" );
    }
    $r->param( "mode",    "editDomainUser" );
    $r->param( "section", "EmailForwards" );
    $self->editDomainUser($r);

}

sub deleteMailDrop {
    my $self = shift;
    my $r    = shift;

    if ( $r->param("mailForwardingAddress") ) {
        my $uid                   = $self->userid2uid( $r->param("user") );
        my $forwardsHash          = {};
        my $mailForwardingAddress =
          $self->as_arrayref(
            $self->{'ispman'}->getMailForwardsForUser( $uid, $self->{'domain'} )
          );

        #print $self->html_dumper($mailForwardingAddress);

        if ($mailForwardingAddress) {

            #fill up the hash with all mailAliases.
            for (@$mailForwardingAddress) {
                $forwardsHash->{$_}++;
            }

            #print $self->html_dumper($forwardsHash);
            #now delete the ones that we are being passed.
            for ( $r->param("mailForwardingAddress") ) {
                delete $forwardsHash->{$_};
            }

          #print $self->html_dumper($forwardsHash);
          #call replaceMailAliasForUser method with reference to list of aliases
            $self->replaceMailForwardForUser( $uid, $self->{'domain'},
                [ keys %$forwardsHash ] );
        }
    }

    $r->param( "mode",    "editDomainUser" );
    $r->param( "section", "EmailForwards" );
    $self->editDomainUser($r);

}

sub userid2uid {
    my $self     = shift;
    my $username = shift;
    return $self->{'ispman'}->create_uid( $username, $self->{'domain'} );
}

sub uid2userid {
    my $self = shift;
    my $uid  = shift;
    $uid =~ s/\_.*//g
      ;    #delete everything from first _, the name is already fully qualified.
    return lc($uid);
}

sub userExists {
    my $self = shift;

    #overrides the ISPMan::userExists;
    my $user = shift;
    my $uid  = $self->userid2uid($user);

    #print "UID is $uid<br>";

    my $dn = "uid=$uid, ou=users, $self->{'domaindn'}";

    #print "DN is $dn<br>";

    return $self->{'ispman'}->getCount($dn);
}

1;

__END__

