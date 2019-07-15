package CustomerMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $Config);

sub editVhost {
    my $self = shift;
    my $r    = shift;
    my $text = shift;

    $r->param( "ispmanDomain", $self->{'domain'} );

    unless ( $r->param("vhost") ) {
        my $template =
          $self->getTemplate("customerMan/websites/editVhostHeader.tmpl");
        print $template->fill_in( PACKAGE => "CustomerMan" );
        return;
    }

    $r->param( "cn", $r->param("vhost") );

    my $template =
      $self->getTemplate("customerMan/websites/editVhostHeader.tmpl");
    $text .= $template->fill_in( PACKAGE => "CustomerMan" );

    unless ( $r->param("section") ) {
        $r->param( "section", "WebsiteInfos" );
    }

    $template =
      $self->getTemplate( join "",
        ( "customerMan/websites/editVhost", $r->param("section"), ".tmpl" ) );
    $text .= $template->fill_in( PACKAGE => "CustomerMan" );

#$text.= $template->fill_in() || "<font color=red>This module is currently not available</font>";

    $template = $self->getTemplate("customerMan/websites/editVhostFooter.tmpl");
    $text .= $template->fill_in( PACKAGE => "CustomerMan" );

    #$text.= $template->fill_in();

    print $text;

}

sub displayVhosts {
    my $self = shift;
    my $r    = shift;

    my $template =
      $self->getTemplate("customerMan/websites/displayVhosts.tmpl");
    print $template->fill_in();
}

sub displayAddVhostForm {
    my $self     = shift;
    my $r        = shift;
    my $template =
      $self->getTemplate("customerMan/websites/displayAddVhostForm.tmpl");
    print $template->fill_in();
}

sub getVhosts {
    my $self   = shift;
    my $domain = $self->{'domain'};
    my $base   = $self->{'ispman'}->getConf("ldapBaseDN");
    my $dn     = "ou=httpdata, ispmanDomain=$domain, $base";
    my $vhosts = $self->{'ispman'}->getApacheVhosts($dn);
    return $vhosts;
}

sub deleteVhost {
    my $self = shift;
    my $r    = shift;

    my $vhost  = $r->param("cn");
    my $domain = $self->{'domain'};
    my $base   = $self->{'ispman'}->getConf("ldapBaseDN");
    my $dn = "ispmanVhostName=$vhost, ou=httpdata, ispmanDomain=$domain, $base";

    $r->param( "ispmanDomain", $domain );
    $r->param( "dn",           $dn );

    if ( $self->{'ispman'}->deleteVhost( $r, 1 ) ) {
        $self->editVhost($r);
    }

}

sub getDomainVhostQuota {
    my $self       = shift;
    my $domain     = $self->{'domain'};
    my $domainInfo = $self->{'ispman'}->getDomainInfo( $domain, 1 );
    return $domainInfo->{'ispmanMaxVhosts'};
}

sub getDomainVhostInfo {
    my $self      = shift;
    my $r         = shift;
    my $vhost     = $r->param("vhost");
    my $domain    = $self->{'domain'};
    my $vhostInfo = $self->{'ispman'}->getVhostInfo( $vhost, $domain );
    return $vhostInfo;
}

sub getWebsiteAliases {
    my $self      = shift;
    my $vhostInfo = $self->getDomainVhostInfo(@_);
    use Data::Dumper;
    print Dumper($vhostInfo);

}

sub changeWebsiteInfos {
    my $self                = shift;
    my $r                   = shift;
    my $vhost               = $r->param("cn");
    my $domain              = $self->{'domain'};
    my @documentrootoptions = ();
    my @scriptdiroptions    = ();

    for ( $r->param ) {
        if (/^documentrootoption/) {
            if ( $r->param($_) ) {
                push @documentrootoptions, $r->param($_);
            }
        }
        if (/^scriptdiroption/) {
            if ( $r->param($_) ) {
                push @scriptdiroptions, $r->param($_);
            }
        }
    }

    my $dn   = "ispmanVhostName=$vhost, ou=httpdata, $self->{'domaindn'}";
    my $data = {};
    $data->{"ispmanVhostDocumentRootOption"} = \@documentrootoptions;
    $data->{"ispmanVhostScriptDirOption"}    = \@scriptdiroptions;

    if ( $self->updateEntryWithData( $dn, $data ) ) {
        $self->addProcessToGroup( $domain, "httpgroup", "ModifyVirtualHost",
            $r->param("cn") );
    }

    $r->param( "vhost", $vhost );
    $self->editVhost($r);
}

sub addWebsiteAlias {
    my $self = shift;
    my $r    = shift;
    print $r->as_string;

    my $alias = $r->param("alias");
    $alias =~ s/\.$self->{'domain'}//;
    $alias = join '.', ( $alias, $self->{'domain'} );
    my $vhost = $r->param("vhost");

    my $dn = "ispmanVhostName=$vhost, ou=httpdata, $self->{'domaindn'}";

    print "Alias: $alias";

    if (
        $self->{'ispman'}->getCount(
            "ou=httpdata, $self->{'domaindn'}",
            "ispmanVhostServerAlias=$alias"
        )
      )
    {
        $r->param( "errors",
"This alias already exists for another website in your domain<br>Please choose another alias"
        );
    }
    else {
        $r->param( "message",
            "Adding Website  alias $alias for $vhost.$self->{'domain'}" );
        $self->{'ispman'}
          ->addData2Entry( $dn, { "ispmanVhostServerAlias" => $alias } );
    }

    $self->addProcessToGroup( $r->param("ispmanDomain"),
        "httpgroup", "ModifyVirtualHost", $vhost );
    $r->param( "mode",    "editVhost" );
    $r->param( "section", "WebsiteAliases" );
    $self->editVhost($r);
}

sub updateWebsiteAliases {
    my $self    = shift;
    my $r       = shift;
    my $vhost   = $r->param("cn");
    my $dn      = "cn=$vhost, ou=httpdata, $self->{'domaindn'}";
    my @aliases = ();

    for ( $r->param("serveralias") ) {
        if (/\S/) {
            s/\.$self->{'domain'}$//;
            push @aliases, "$_\.$self->{'domain'}";
        }
    }
    my $vhostInfo = $self->{'ispman'}->getVhostInfo($vhost,$self->{'domain'});
    if (@aliases) {
        if ( $self->modifyAttribute( $dn, 'serveralias', \@aliases ) ) {
            $self->addProcessToGroup(
                $self->{'domain'},   "httpgroup",
                "ModifyVirtualHost", $r->param("cn")
            );
        }
        $vhostInfo->{'serveralias'} = \@aliases;
    }
    else {
        delete $vhostInfo->{'serveralias'};
        $self->deleteAttributes( $dn, ["serveralias"] );
    }

    $r->param( "mode",    "editVhost" );
    $r->param( "section", "WebsiteAliases" );
    $r->param( "vhost",   $vhost );
    $self->editVhost($r);

}

sub addHttpUser {
    my $self = shift;
    my $r    = shift;

    #FIXME:: add code to check if the user does not exist
    # add code to create this branch if it does not exist

    #check if ou=httpusers, ispmanDomain=domain, o=ldapBaseDN exists.
    #if not, then create it.
    my $branch = "ou=httpusers, " . $self->{'domaindn'};
    $self->prepareBranchForDN($branch);

    my $dn = join "",
      (
        "ispmanUserId=",   $r->param("newusername"),
        ",ou=httpUsers, ", $self->{'domaindn'}
      );

    my $data = {
        "ispmanUserId" => $r->param("newusername"),
        "ispmanDomain" => $self->{'domain'},
        "objectclass"  => "ispmanVirtualHostUser"
    };

    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $r->param("newuserpassword"),
        $self->getConf('userPassHashMethod') );

    $self->addNewEntryWithData( $dn, $data );
    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "HttpUsers" );
    $self->advanceItems($r);
}

sub deleteHttpUser {
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    $self->deleteEntry($dn);

    $r->param( "mode",    "advanceItems" );
    $r->param( "section", "HttpUsers" );
    $self->advanceItems($r);
}

sub updateHttpUser {

#updating a user is to delete and recreate a user since userid is part of the dn.
    my $self = shift;
    my $r    = shift;
    my $dn   = $r->param("dn");
    $self->deleteEntry($dn);
    $r->param( "newusername",     $r->param("userid") );
    $r->param( "newuserpassword", $r->param("userpassword") );
    $r->delete("userid");
    $r->delete("userpassword");
    $self->addHttpUser($r);
}

sub getWebUsers {
    my $self = shift;
    return $self->getEntriesAsHashRef(
        "ou=httpUsers, @{[$self->{'domaindn'}]}",
        "objectclass=ispmanVirtualHostUser",
        [ "ispmanUserId", "userpassword" ]
    );

}

1;

__END__

