package ISPMan::ResellerMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $ispman);
require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  formAddReseller
  AddReseller
  addReseller
  showResellers
  editReseller
  getResellers
  getResellerById
  getNewResellerId
  getResellerNameById
  getResellerDnById
  ModifyReseller
  SuspendReseller
  ReactivateReseller
  DeleteReseller
  getResellerAttributes

  changeResellerPassword
  ispmanSuspendResellers
  ispmanReactivateResellers
  ispmanDeleteResellers

);

sub getResellerAttributes {

    #return list of modifyable attributes for a reseller
    my $self = shift;

    return qw (
      uid
      userPassword
      ispmanStatus
      ispmanResellerName
      sn
      givenName
      street
      postalCode
      l
      c
      ispmanResellerMaxClients
      telephoneNumber
      facsimileTelephoneNumber
      cn
    );
}

sub getNewResellerId {
    my $self  = shift;
    my $entry =
      $self->getEntry(
        "cn=resellercounter, ou=counters, $self->{'Config'}{'ldapBaseDN'}");
    my $currid = $entry->get_value("currid");
    $self->updateEntryWithData(
        "cn=resellercounter, ou=counters, $self->{'Config'}{'ldapBaseDN'}",
        { "currid" => ++$currid } );
    return $currid;
}

sub getResellerNameById {
    my $self = shift;
    my $id   = shift;

    return undef unless $id;

    $self->getResellerById($id);
    return $self->{'reseller'}{'ispmanResellerName'};
}

sub getResellerDnById {
    my $self = shift;
    my $id   = shift;
    return "ispmanResellerId=$id, ou=ispman, $self->{'Config'}{'ldapBaseDN'}";
}

sub formAddReseller {
    my $self = shift;
    my $r    = shift;

    if ( $r->param("ispmanResellerId") ) {
        $self->getResellerNameById( $r->param("ispmanResellerId") );
    }
    my $template = $self->getTemplate("resellers/add_edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub addReseller {
    my $self = shift;

    my $r  = shift;
    my $id = $self->getNewResellerId();
    $r->param( "ispmanResellerId", $id );
    $r->param(
        "userPassword",
        $self->encryptPassWithMethod(
            $r->param("userPassword"),
            $self->getConf('userPassHashMethod')
        )
    );

    $self->addDataFromLdif( 'templates/reseller.ldif.template', $r );
    $self->{'message'} = "Reseller Added. Id: $id";

    #$self->editReseller($r);
}

sub AddReseller {
    my $self = shift;
    my $r    = shift;
    $self->addReseller($r);
    $self->showResellers($r);
}

sub getResellers {
    my $self   = shift;
    my $filter = "objectclass=ispmanReseller";
    $self->{'resellers'} =
      $self->getEntriesAsHashRef( $self->{'Config'}{'ldapBaseDN'}, $filter );
    return $self->{'resellers'};
}

sub getResellerById {
    my $self = shift;
    my $id   = shift;
    $self->{'reseller'} =
      $self->getEntryAsHashRef( $self->getResellerDnById($id),
        "ispmanResellerId=$id" );
    return $self->{'reseller'};
}

sub showResellers {
    my $self = shift;
    return
      unless ( $self->{'session'}->param("logintype") eq "reseller"
        || $self->{'session'}->param("logintype") eq "admin" );
    my $template = $self->getTemplate("resellers/list.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub editReseller {
    my $self = shift;
    my $r    = shift;
    $self->getResellerById( $r->param('ispmanResellerId') );
    my $template = $self->getTemplate("resellers/add_edit.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );

}

sub SuspendReseller {
    my $self = shift;
    if ( $self->{'session'}->param("logintype") ne "admin" ) {

        #Only Admin can add resellers
        print "Whatchou talking about, willis?";
        exit;
    }
    my $id = shift;
    $self->updateEntryWithData( $self->getResellerDnById($id),
        { "ispmanStatus" => "suspend" } );

}

sub ReactivateReseller {
    my $self = shift;
    if ( $self->{'session'}->param("logintype") ne "admin" ) {

        #Only Admin can add resellers
        print "Heyhey you must be really sore!!";
        exit;
    }
    my $id = shift;
    $self->updateEntryWithData( $self->getResellerDnById($id),
        { "ispmanStatus" => "active" } );
}

sub DeleteReseller {
    my $self = shift;
    if ( $self->{'session'}->param("logintype") ne "admin" ) {

        #Only Admin can delete resellers
        print "Ouch!! Go away, I don't want to play with you no more.";
        exit;
    }
    my $id = shift;
    $self->delTree( $self->getResellerDnById($id) );
}

sub ModifyReseller {
    my $self               = shift;
    my $r                  = shift;
    my @ResellerAttributes = $self->getResellerAttributes();
    my $data;
    for (@ResellerAttributes) {
        if ( $r->param($_) ) {
            $data->{$_} = $r->param($_);
        }
    }
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $r->param("userPassword"),
        $self->getConf('userPassHashMethod') );
    $self->updateEntryWithData(
        $self->getResellerDnById( $r->param("ispmanResellerId") ), $data );
    $r->param( "mode", "showResellers" );
    $self->showResellers($r);
}

sub ispmanSuspendResellers {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanResellerId") );
    for (@ids) {
        $self->SuspendReseller($_);
    }
    $r->delete("mode");
    $r->param( "mode", "showResellers" );
    $self->showResellers($r);

}

sub ispmanReactivateResellers {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanResellerId") );
    for (@ids) {
        $self->ReactivateReseller($_);
    }
    $r->delete("mode");
    $r->param( "mode", "showResellers" );
    $self->showResellers($r);

}

sub ispmanDeleteResellers {
    my $self = shift;
    my $r    = shift;

    my @ids = $self->as_array( $r->param("ispmanResellerId") );
    for (@ids) {
        $self->DeleteReseller($_);
    }
    $r->delete("mode");
    $r->param( "mode", "showResellers" );
    $self->showResellers($r);
}

sub changeResellerPassword {
    my $self = shift;
    my ( $rid, $pass ) = @_;
    my $dn   = $self->getResellerDnById($rid);
    my $data = {};
    $data->{'userPassword'} =
      $self->encryptPassWithMethod( $pass,
        $self->getConf('userPassHashMethod') );
    return $self->updateEntryWithData( $dn, $data );
}

