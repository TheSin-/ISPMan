package ISPMan::ClientMan;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $ispman);
require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  formAddClient
  addClient
  AddClient
  showClients
  editClient
  getNewClientId
  getClients
  getClientsCount
  getClientById
  getClientNameById
  getClientDnById
  ModifyClient
  SuspendClient
  ReactivateClient
  DeleteClient
  getClientAttributes
  getClientAttributeById
  getDomainCountForClient

  ispmanDeleteClients
  ispmanSuspendClients
  ispmanReactivateClients

  changeClientPassword

);

sub getClientAttributes {

    #return list of modifyable attributes for a reseller
    my $self = shift;

    return qw (
      uid
      cn
      userPassword
      ispmanStatus
      ispmanClientName
      sn
      givenName
      street
      postalCode
      l
      c
      telephoneNumber
      facsimileTelephoneNumber
      ispmanDomainDefaultWebHost
      ispmanDomainDefaultFileServer
      ispmanDomainDefaultMailDropHost
      ispmanClientMaxDomains
      dnsHost
      smtpHost
    );
}

sub getNewClientId {
    my $self  = shift;
    my $entry =
      $self->getEntry(
        "cn=clientcounter, ou=counters, $self->{'Config'}{'ldapBaseDN'}");
    my $currid = $entry->get_value("currid");
    $self->updateEntryWithData(
        "cn=clientcounter, ou=counters, $self->{'Config'}{'ldapBaseDN'}",
        { "currid" => ++$currid } );
    return $currid;
}

sub getClientNameById {
    my $self = shift;
    my $id   = shift;
    $self->getClientById($id);
    return $self->{'client'}{'ispmanClientName'};
}

sub getClientAttributeById {
    my $self = shift;
    my ( $id, $attr ) = @_;
    $self->getClientById($id);
    return $self->{'client'}{$attr};
}

sub getClientDnById {
    my $self = shift;
    my $id   = shift;
    $self->getClientById($id);
    return
"ispmanClientId=$id, ispmanResellerId=$self->{'client'}{'ispmanResellerId'}, ou=ispman, $self->{'Config'}{'ldapBaseDN'}";
}

sub formAddClient {
    my $self     = shift;
    my $template = $self->getTemplate("clients/add_edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub addClient {
    my $self = shift;

    my $r = shift;

    if ( $self->{'session'} ) {
        return
          unless ( $self->{'session'}->param("logintype") eq "reseller"
            or $self->{'session'}->param("logintype") eq "admin" );
        if ( $self->{'session'}->param("logintype") eq "reseller" ) {
            $r->param( "ispmanResellerId",
                $self->{'session'}->param("ispmanResellerId") );
        }
    }

    my $ispmanResellerInfo =
      $self->getResellerById( $r->param("ispmanResellerId") );
    my $ispmanResellerMaxClientLimit =
      $ispmanResellerInfo->{'ispmanResellerMaxClients'};
    my $ispmanResellerClients =
      $self->getClientsCount(
        sprintf( "ispmanResellerId=%s", $r->param("ispmanResellerId") ) );

    unless ( $ispmanResellerClients < $ispmanResellerMaxClientLimit ) {
        $self->{'message'} = "Max client Limit reached or exceeded";
        return;
    }

    my $id = $self->getNewClientId();

    $r->param( "ispmanClientId", $id );

    $r->param( "ispmanResellerName",
        $self->getResellerNameById( $r->param("ispmanResellerId") ) );
    $r->param(
        "userPassword",
        $self->encryptPassWithMethod(
            $r->param("userPassword"),
            $self->getConf('userPassHashMethod')
        )
    );

    $self->addDataFromLdif( 'templates/client.ldif.template', $r );
    $self->{'message'} = "Client Added: ID $id";

}

sub AddClient {
    my $self = shift;
    my $r    = shift;
    $self->addClient($r);
    $self->showClients($r);
}

sub getClients {
    my $self = shift;

    undef $self->{'filter'};
    $self->{'filter'} = shift;

    $self->{'searchFilter'} = "&(objectclass=ispmanClient)";

    if ( $self->{'session'} ) {
        if ( $self->{'session'}->param("logintype") eq "reseller" ) {
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanClient)(ispmanResellerId=%s)",
                $self->{'session'}->param("ispmanResellerId") );
        }
        elsif ( $self->{'session'}->param("logintype") eq "client" ) {
            $self->{'searchFilter'} =
              sprintf( "&(objectclass=ispmanClient)(ispmanClientId=%s)",
                $self->{'session'}->param("ispmanClientId") );
        }
    }

    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    $self->{'clients'} =
      $self->getEntriesAsHashRef( $self->{'Config'}{'ldapBaseDN'},
        $self->{'searchFilter'} );
    return $self->{'clients'};

}

sub getClientById {
    my $self = shift;
    my $id   = shift;

    $self->{'client'} = $self->getEntryAsHashRef(
        $self->{'Config'}{'ldapBaseDN'},
        "&(ispmanClientId=$id)(objectclass=ispmanClient)",
        [], "sub"
    );
    return $self->{'client'};
}

sub showClients {
    my $self = shift;
    my $r    = shift;
    my $id   =
      ( defined $r->param("ispmanResellerId") )
      ? $r->param("ispmanResellerId")
      : "";
    $self->getClients($id);
    my $template = $self->getTemplate("clients/list.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub editClient {
    my $self = shift;
    my $r    = shift;
    print "Getting info about ", $r->param('ispmanClientId');
    $self->getClientById( $r->param('ispmanClientId') );
    my $template = $self->getTemplate("clients/add_edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub formSuspendOrDeleteClients {
    my $self     = shift;
    my $r        = shift;
    my $template = $self->getTemplate("clients/suspend_or_delete.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub SuspendClient {
    my $self = shift;
    my $id   = shift;
    $self->updateEntryWithData( $self->getClientDnById($id),
        { "ispmanStatus" => "suspend" } );

}

sub ReactivateClient {
    my $self = shift;
    my $id   = shift;
    $self->updateEntryWithData( $self->getClientDnById($id),
        { "ispmanStatus" => "active" } );

}

sub DeleteClient {
    my $self = shift;
    my $id   = shift;
    $self->delTree( $self->getClientDnById($id) );
}

sub ModifyClient {
    my $self = shift;
    my $r    = shift;

    my $dn   = $self->getClientDnById( $r->param("ispmanClientId") );
    my $data = $self->getEntryAsHashRef($dn);

    # take over easily changeable attributes
    my @ClientAttributes = $self->getClientAttributes();
    for (@ClientAttributes) {
        $data->{$_} = $self->as_arrayref( $r->param($_) )
          if ( $r->param($_) );
    }

    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $r->param("userPassword"),
        $self->getConf('userPassHashMethod') );

    # only admin may change reseller this client belongs to
    if ( $r->param("ispmanResellerId")
        && $self->{'session'}->param('logintype') eq 'admin'
        && $data->{'ispmanResellerId'} != $r->param("ispmanResellerId") )
    {
        $data->{'ispmanResellerId'}   = $r->param("ispmanResellerId");
        $data->{"ispmanResellerName"} =
          $self->getResellerNameById( $data->{'ispmanResellerId'} );

        # move client's entry
        #print "Deleting $dn<br>";
        $self->deleteEntry($dn);
        $dn =
            'ispmanClientId='
          . $data->{'ispmanClientId'}
          . ', ispmanResellerId='
          . $data->{'ispmanResellerId'}
          . ', ou=ispman, '
          . $self->{'Config'}{'ldapBaseDN'};

        #print "Adding $dn<br>";
        $self->addNewEntryWithData( $dn, $data );
    }
    else {

    #just in case Reseller's face name is changed. Change it also for the client
        $data->{"ispmanResellerName"} =
          $self->getResellerNameById( $data->{'ispmanResellerId'} );

        #print "Updating $dn<br>";
        $self->updateEntryWithData( $dn, $data );
    }

    $r->param( "mode", "showClients" );
    $self->showClients($r);
}

sub getClientsCount {
    my $self = shift;

    undef $self->{'filter'};
    $self->{'filter'} = shift;

    $self->{'searchFilter'} = "&(objectclass=ispmanClient)";
    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    return $self->getCount( $self->{'Config'}->{'ldapBaseDN'},
        "$self->{'searchFilter'}", );
}

sub getDomainCountForClient {
    my $self     = shift;
    my $clientId = shift;
    return $self->getDomainsCount("ispmanClientId=$clientId");
}

sub ispmanSuspendClients {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanClientId") );
    for (@ids) {
        $self->SuspendClient($_);
    }
    $r->param( "mode", "showClients" );
    $self->showClients($r);

}

sub ispmanReactivateClients {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanClientId") );
    for (@ids) {
        $self->ReactivateClient($_);
    }
    $r->param( "mode", "showClients" );
    $self->showClients($r);

}

sub ispmanDeleteClients {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanClientId") );
    for (@ids) {
        $self->DeleteClient($_);
    }
    $r->param( "mode", "showClients" );
    $self->showClients($r);

}

sub changeClientPassword {
    my $self = shift;
    my ( $cid, $pass ) = @_;
    my $dn   = $self->getClientDnById($cid);
    my $data = {};
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    return $self->updateEntryWithData( $dn, $data );
}

