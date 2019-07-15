package ISPMan::LDAP;

use strict;
use Net::LDAP qw(:all);
use Net::LDAP::Entry;
use Net::LDAP::LDIF;
use IO::Scalar;

use Net::LDAP::Util
  qw(ldap_error_desc ldap_error_name ldap_error_text canonical_dn);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $LDAP);
use ISPMan::Utils;

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  ldap_bind
  ldap_ping
  getAclId
  getUid
  getGid
  entries2HashRef
  getEntriesAsHashRef
  getEntries
  getEntryAsHashRef
  getEntry
  addData2Entry
  addNewEntryWithData
  updateEntryWithData
  updateEntry
  deleteEntry
  getCount
  getChildrenCount
  entryExists
  fixLdif
  deleteAttributes
  addRoaming
  deleteRoaming
  addDataFromLdif
  modifyAttribute
  delTree
  getSchemaAttr
  prepareBranchForDN
  branchExists
  isReservedUid
  isReservedGid
  dumpEntry
  removeEmptryAttributes
  lat2utf_ldif_entry
  get_attr_value
);
$VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self;
    ( $self->{'basedn'}, $self->{'host'}, $self->{'user'}, $self->{'pass'} ) =
      @_;

#if I try to call a routine that is in ISPMan, then $self is passed which is an object of ISPMan::LDAP class.
# the sub in the parent routine tries to call $self->{'ldap'}->something and fails, cause the objects from class ISPMan
# have an entry for ->{'ldap'} which maps to this object.
# so mapping $self->{'ldap'} to $self.  Any one has any better way of doing this?

    $self->{'ldap'} = $self;    # :) Hack.
    return bless $self, $class;
}

sub setConfig {
    my $self = shift;
    $self->{'Config'} = shift;
}

# TEMP HACK
# this should work while we are substituting attributes.
# so we can use the same attributes in templates etc
# in future this function should go away completely

sub getSchemaAttr {
    my $self = shift;
    my $attr = shift;

    if ( $self->{'Config'}{'ldapAttrMap'}{$attr} ) {
        return $self->{'Config'}{'ldapAttrMap'}{$attr};
    }
    else {
        return $attr;
    }
}

sub connect {
    my $self      = shift;
    my $reconnect = shift;

    if ( !$LDAP || $reconnect ) {

        #if ($LDAP=Net::LDAP->new($self->{'host'} , onerror => \&LDAPERROR)  ){
        if (
            $LDAP = Net::LDAP->new(
                $self->{'host'}, version => $self->{'Config'}->{'ldapVersion'}
            )
          )
        {
            $self->ldap_bind();
        }
        else {
            print STDERR "Cannot make a connection to LDAP server";
            return 0;
        }
    }
    return 1;
}

sub ldap_bind {
    my $self = shift;

    my $result =
      $LDAP->bind( dn => $self->{'user'}, password => $self->{'pass'} );
    if ( $result->code ) {
        return 0;
    }

    $self->{'connected'}++;
    $self->log_event("Connected to LDAP Server $self->{'host'}")
      unless $self->{'Config'}{'debug'} == 0;
}

sub ldap_ping {
    my $self = shift;
    return 0 unless $LDAP;

    my $mesg = $LDAP->search(
        base   => "@{[$self->SUPER::getConf('ldapBaseDN')]}",
        scope  => "base",
        filter => "objectclass=*"
    );
    return 0 if $mesg->code;
    return 1;
}

sub connected {
    my $self = shift;
    return $self->{'connected'};
}

sub isReservedUid {
    my $self = shift;
    my $uid  = shift;

    $self->log_event("Checking for uid reservation for uid $uid");
    my $isReserved = 0;
    my $entry      = $self->getEntry(
        "cn=uidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        "", ["ispmanResUid"]
    );
    my @reserved = $entry->get_value("ispmanResUid");
    for (@reserved) {
        $isReserved++ if $_ == $uid;
    }
    return $isReserved;
}

sub isReservedGid {
    my $self = shift;
    my $gid  = shift;
    $self->log_event("Checking for gid reservation for gid $gid");
    my $isReserved = 0;
    my $entry      = $self->getEntry(
        "cn=gidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        "", ["ispmanResGid"]
    );
    my @reserved = $entry->get_value("ispmanResGid");
    for (@reserved) {
        $isReserved++ if $_ == $gid;
    }
    if ($isReserved) {
        $self->log_event("Gid $gid was reserved");
    }
    else {
        $self->log_event("Gid $gid was NOT reserved");
    }
    return $isReserved;
}

sub getUid {
    my $self  = shift;
    my $entry = $self->getEntry(
        "cn=uidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        "",
        [ "ispmanResUid", "ispmanCurrUid", "ispmanMaxUid", "ispmanMinUid" ]
    );
    my $uid =
      ( $entry->get_value("ispmanCurrUid") < $entry->get_value("ispmanMinUid") )
      ? $entry->get_value("ispmanMinUid")
      : $entry->get_value("ispmanCurrUid");

    while ( $self->isReservedUid($uid) ) {
        $uid++;
    }
    $self->updateEntryWithData(
        "cn=uidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        { "ispmanCurrUid" => ++$uid }
    );
    return $uid;
}

sub getGid {
    my $self  = shift;
    my $entry = $self->getEntry(
        "cn=gidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        "",
        [ "ispmanResGid", "ispmanCurrGid", "ispmanMaxGid", "ispmanMinGid" ]
    );
    my $gid =
      ( $entry->get_value("ispmanCurrGid") < $entry->get_value("ispmanMinGid") )
      ? $entry->get_value("ispmanMinGid")
      : $entry->get_value("ispmanCurrGid");

    while ( $self->isReservedGid($gid) ) {
        $gid++;
    }

    $self->updateEntryWithData(
        "cn=gidcounter, ou=counters, @{[$self->SUPER::getConf('ldapBaseDN')]}",
        { "ispmanCurrGid" => ++$gid }
    );
    return $gid;
}

sub getAclId {
    my $self = shift;

    unless (
        $self->entryExists(
            "cn=aclidcounter, ou=counters, @{[$self->getConf('ldapBaseDN')]}")
      )
    {
        $self->addDataFromLdif("templates/aclid.counter.ldif.template");
        return 1;
    }

    my $entry =
      $self->getEntry(
        "cn=aclidcounter, ou=counters, @{[$self->getConf('ldapBaseDN')]}",
        "objectClass=*", ["ispmanCurrAclId"] );

    my $aclid = $entry->get_value("ispmanCurrAclId");
    $self->updateEntryWithData(
        "cn=aclidcounter, ou=counters, @{[$self->getConf('ldapBaseDN')]}",
        { "ispmanCurrAclId" => ++$aclid } );
    return $aclid;
}

sub entries2HashRef {
    my $self  = shift;
    my $entry = shift;
    return unless $entry;

    if ( $self->{'Config'}->{'debug'} == 3 ) {
        $self->log_event( "Called by ", caller );
        $self->log_event("Receiveing $entry to change2 hashref");
    }
    my $temphash = {};
    my @vals;

    for my $attr ( $entry->attributes() ) {

        @vals = ();
        undef @vals;
        @vals = $entry->get_value($attr);

        if ( scalar(@vals) > 1 ) {
            $temphash->{$attr} = $self->utf2lat( $self->as_arrayref(@vals) );
        }
        else {
            $temphash->{$attr} = $self->utf2lat( $vals[0] );
        }
    }

    return $temphash;
}

sub getEntriesAsHashRef {
    my $self    = shift;
    my @entries = $self->getEntries(@_);

    my $dn;
    my $hashref;
    my $temphash;

    my @vals;

    for (@entries) {
        $hashref->{ $_->dn() } = $self->entries2HashRef($_);
    }

    return $hashref;

}

sub getCachedEntriesAsHashRef {
    my $self = shift;
    my $x = join ":", @_;
    print "$x\n";

    if ( $self->{'ldapcache'}{$x} ) {
        return $self->{'ldapcache'}{$x};
    }
    else {
        my @entries = $self->getEntries(@_);

        my $dn;
        my $hashref;
        my $temphash;

        my @vals;

        for (@entries) {
            $hashref->{ $_->dn() } = $self->entries2HashRef($_);
        }
        $self->{'ldapcache'}{$x} = $hashref;
        return $self->{'ldapcache'}{$x};

    }
}

sub getEntries {
    my $self = shift;
    my ( $base, $filter, $attr, $scope ) = @_;
    $filter ||= "objectClass=*";
    $scope  ||= "sub";

    my $mesg = $LDAP->search(
        base    => $base,
        scope   => $scope,
        filter  => "($filter)",
        "attrs" => $attr
    );
    my @entries = $mesg->sorted;
    return @entries;

}

sub getCount {
    my ( $self, $base, $filter, $attr, $scope ) = @_;
    $filter ||= "objectClass=*";
    $attr   ||= [];
    $scope  ||= "sub";

    my $mesg = $LDAP->search(
        base    => $base,
        scope   => $scope,
        filter  => "($filter)",
        "attrs" => $attr
    );
    return $mesg->count;
}

sub getChildrenCount {
    my ( $self, $base, $filter, $attr ) = @_;
    $filter ||= "objectClass=*";
    my $mesg = $LDAP->search(
        base    => $base,
        scope   => "one",
        filter  => "($filter)",
        "attrs" => $attr
    );
    return $mesg->count;
}

sub entryExists {
    my $self = shift;
    return $self->getCount(@_);
}

sub branchExists {
    my ( $self, $base ) = @_;
    my $mesg = $LDAP->search(
        base   => $base,
        scope  => "base",
        filter => "(objectClass=*)"
    );
    return $mesg->count;
}

sub getEntry {
    my $self = shift;
    my ( $dn, $filter, $attrs, $scope ) = @_;

    $filter ||= "objectClass=*";
    $scope  ||= "base";

    if ( $self->branchExists($dn) ) {
        my $mesg = $LDAP->search(
            base    => $dn,
            scope   => $scope,
            filter  => "($filter)",
            "attrs" => $attrs
        );
        my ($entry) = $mesg->entry(0);
        return $entry;
    }
}

sub get_attr_value {
    my $self = shift;

    my ( $entry, $attr ) = @_;
    return $self->utf2lat( $entry->get_value( $attr, asref => 1 ) );
}

sub getEntryAsHashRef {
    my $self = shift;
    if ( $self->{'Config'}->{'debug'} == 3 ) {
        $self->log_event( "Sub getEntryAsHashRef called by ", caller );
        $self->log_event("Getting @_ and passing to entries2HashRef");
    }
    return $self->entries2HashRef( $self->getEntry(@_) );
}

sub try {
    my $result = shift;
    my $dn     = shift;

    my ( $package, $filename, $line ) = caller;

    if ( $result->code ) {
        print "DN passed: $dn\n";
        LDAPerror( "Searching", $result );
        print "<br>Package: $package\n";
        print "<br>Filename: $filename\n";
        print "<br>Line: $line\n";
        return 0;
    }
    else {
        return 1;
    }
}

sub LDAPerror {
    my ( $from, $mesg ) = @_;
    print "<pre>\n";

    print "Return code: ", $mesg->code, "\n";
    print "Error name: ", ldap_error_name( $mesg->code ), "\n";
    print "Error text: ", ldap_error_text( $mesg->code ), "\n";
    print "Error desc: ", ldap_error_desc( $mesg->code ), "\n";
    print "MessageID: ",    $mesg->mesg_id,      "\n";
    print "Error: ",        $mesg->error,        "\n";
    print "Server Error: ", $mesg->server_error, "\n";

    print "DN: ", $mesg->dn, "\n";
    print "Canonical DN: ", canonical_dn( $mesg->dn ), "\n";

    print "\n</pre>\n";
}

sub LDAPERROR {
    my ($mesg) = @_;
    print "<pre>\n";

    print "Return code: ", $mesg->code, "\n";
    print "Error name: ", ldap_error_name( $mesg->code ), "\n";
    print "Error text: ", ldap_error_text( $mesg->code ), "\n";
    print "Error desc: ", ldap_error_desc( $mesg->code ), "\n";
    print "MessageID: ",    $mesg->mesg_id,      "\n";
    print "Error: ",        $mesg->error,        "\n";
    print "Server Error: ", $mesg->server_error, "\n";

    print "DN: ", $mesg->dn, "\n";
    print "Canonical DN: ", canonical_dn( $mesg->dn ), "\n";

    print "\n</pre>\n";
}

sub delTree {
    my $self = shift;
    my $dn   = shift;
    my $mesg =
      $LDAP->search( base => $dn, filter => "(objectClass=*)", "attrs" => [] );
    my @entries = $mesg->sorted;
    for ( reverse @entries ) {
        ;
        $self->deleteEntry( $_->dn() );
    }
    return 1;
}

sub modifyAttribute {
    my ( $self, $dn, $attribute, $data ) = @_;
    $self->updateEntryWithData( $dn, { $attribute => $data } );
}

sub deleteAttributes {
    my $self       = shift;
    my $dn         = shift;
    my $attributes = shift;
    my $entry      = $self->getEntry($dn);
    $entry->delete(@$attributes);
    try( $entry->update($LDAP) );
}

sub updateEntryWithData {
    my $self = shift;
    my $dn   = shift;
    my $data = shift;

    my $entry = $self->getEntry($dn);

    my $changed = 0;
    for ( keys %$data ) {
        if ( !$self->isEmpty( $data->{$_} ) ) {

            #convert value from latin1 to utf8
            $data->{$_} = $self->lat2utf( $data->{$_} );
            if ( $entry->exists($_) ) {
                if ( $self->{'Config'}->{'debug'} == 3 ) {
                    print "Entry exists. Replacing $_ with ", $data->{$_},
                      "<br>\n";
                }
                $entry->replace( $_, $data->{$_} ) && $changed++;
            }
            else {
                if ( $self->{'Config'}->{'debug'} == 3 ) {
                    print "Entry does not exist. Adding $_ with ", $data->{$_},
                      "<br>\n";
                }
                $entry->add( $_, $data->{$_} ) && $changed++;
            }
        }
        else {
            if ( $entry->exists($_) ) {
                if ( $self->{'Config'}->{'debug'} == 3 ) {
                    print "Entry exists for $_ : Deleting it. <br>\n";
                }
                $entry->delete($_) && $changed++;
            }
        }
    }

    if ( $self->{'Config'}->{'debug'} == 3 ) {
        $self->dumpEntry($entry);
    }

    if ($changed) {
        $entry = $self->removeEmptryAttributes($entry);
        try( $entry->update($LDAP) );
    }
}

sub addNewEntryWithData {
    my $self = shift;
    my $dn   = shift;
    my $data = shift;

    # don't give error. just quit
    # ATIF FixME: 10 May 2002.
    # In future there should be some error reporting mech
    # sort of an array of error array etc.

    $self->log_event("Adding entry for $dn");

    return if $self->entryExists($dn);

    my $entry = Net::LDAP::Entry->new();
    $entry->changetype("add");
    $entry->dn($dn);

    # get the first attrib name and val and
    # add them in the entry if the don't exists.
    my ( $attrib, $attribval ) = $dn =~ m/^(\w+)?\=([^,]*)/;
    $data->{$attrib} =
      $self->as_arrayref(
        $self->unique( $self->as_array( $data->{$attrib}, $attribval ) ) );

    if ( $self->{'Config'}->{'debug'} == 3 ) {
        print "Attrib is $attrib\n";
        print "AttribVal is $attribval\n";
    }

#if ($dn=~m/^ou=/){
#   #$data->{'objectclass'}=$self->as_arrayref($self->unique($self->as_array($data->{"objectclass"} , "organizationalUnit")));
#   my ($ou)=$dn=~m/^ou=([^,]+)/;
#   $data->{'ou'}=$self->as_arrayref($self->unique($self->as_array($data->{"ou"} , $ou)));
#}

    for ( keys %$data ) {
        if ( !$self->isEmpty( $data->{$_} ) ) {

            #convert value from latin1 to utf8
            $data->{$_} = $self->lat2utf( $data->{$_} );
            $entry->add( $_, $data->{$_} );
        }
        else {

            # 2002-02-07.
            # ATIF: TEST ME
            # don't add an attribute if it is blank
            # lets see if this breaks anything
            # $entry->add($_, "");
        }
    }

    $entry = $self->removeEmptryAttributes($entry);
    if ( $self->{'Config'}->{'debug'} == 3 ) {
        print "Dumping Entry\n";
        print $entry->dump();
    }
    try( $entry->update($LDAP), $dn );
}

sub addData2Entry {
    my $self = shift;
    my $dn   = shift;
    my $data = shift;
    if ( $self->{'Config'}->{'debug'} == 3 ) {
        print qq|
      <pre>
      
      ISPMan::LDAP->addData2Entry

      Recieveing:

      dn: $dn
      data 

      |;
        print $self->dumper($data);

        print "\n</pre>";

    }

    my $entry = $self->getEntry($dn);

    for ( keys %$data ) {
        if ( !$self->isEmpty( $data->{$_} ) ) {

            #convert value from latin1 to utf8
            $data->{$_} = $self->lat2utf( $data->{$_} );
            $entry->add( $_, $data->{$_} );
        }
    }
    $entry = $self->removeEmptryAttributes($entry);
    try( $entry->update($LDAP) );
}

sub dumpEntry {
    my $self  = shift;
    my $entry = shift;
    return unless ref $entry eq "Net::LDAP::Entry";

    if ( $ENV{'HTTP_USER_AGENT'} ) {
        print "<pre>\n";
        $entry->dump();
        print "\n</pre>\n";
    }
    else {
        $entry->dump;
    }
}

sub updateEntry {
    my $self = shift;
    my $r    = shift;

    my $entry = $self->getEntry( $r->param("dn") );
    for ( $entry->attributes ) {
        if ( $self->{'Config'}->{'debug'} == 3 ) {
            $self->log_event("Attribute $_");
        }
        if ( $r->param($_) ) {
            $self->log_event( "Replacing $_ with ", $r->param($_) );

            $entry->replace( $_, $self->lat2utf( $r->param($_) ) );
        }
    }
    $entry = $self->removeEmptryAttributes($entry);
    try( $entry->update($LDAP) );
}

sub addEntry {
    my $self   = shift;
    my $attrib = shift;
    my $r      = shift;

    my $entry = $self->getEntry( $r->param("dn") );
    $entry->add( $attrib, $self->lat2utf( $r->param($attrib) ) );
    try( $entry->update($LDAP) );
}

sub deleteEntry {
    my $self = shift;
    my $dn   = shift;

    # don't give error. just quit
    # ATIF FixME: 10 May 2002.
    # In future there should be some error reporting mech
    # sort of an array of error array etc.
    return unless $self->entryExists($dn);

    my $entry = Net::LDAP::Entry->new();
    $entry->changetype("delete");
    $entry->dn($dn);
    $self->log_event( "Trying to delete ", $dn, "from LDAP" );

    $entry->delete();
    if ( try( $entry->update($LDAP) ) ) {
        $self->log_event("Entry deleted from LDAP");
        return 1;
    }
}

sub addDataFromLdif {
    my $self = shift;
    my $ldif = shift;
    my $r    = shift;

    $self->log_event("getting $ldif") if $self->getConfig("debug") > 1;

    if ( $r && ref $r eq "CGI" ) {
        $ISPMan::domain = $r->param("ispmanDomain");
        $ISPMan::r      = $r;
    }
    elsif ( $r && ref $r eq "HASH" ) {

        #we are passing a hash instead of a CGI object
        for ( keys %$r ) {
            eval("\$ISPMan::$_ = '$r->{$_}'");
        }
    }

    $ISPMan::ispman = $self;
    my $domain = $ISPMan::domain;

    # if not called with a path starting with a /, then use the installDir+path
    # else use the path that was given.
    # useful for external apps
    my $installDir = $self->{'Config'}{'installDir'}
      || $self->getConf("installDir");
    my $tmpl_directory;    # these are the ldif templates
    my $source_ldif;

    if ( $ldif =~ /^\// ) {
        $source_ldif = $ldif;
    }
    else {
        if ( -d join "/", ( $self->getConf("installDir"), "templates" ) ) {
            $tmpl_directory =
              $self->getConf("installDir")
              ;    #base directory. Calls comming in with template/filename.ldif
        }
        else {

 # for maintainers. install-data/templates  so we shall add install-data to base
            $tmpl_directory = join "/",
              ( $self->getConf("installDir"), "install-data" );
        }
        $source_ldif = join "/", ( $tmpl_directory, $ldif );
    }
    my $template = $self->getTemplate($source_ldif);

    my $text = $self->fixLdif( $template->fill_in( PACKAGE => "ISPMan" ) );

    #uncomment for debuggin
    #print "Getting $ldif <br><br>";
    #print $self->html_dumper($text);
    #return;

    tie *OUT, 'IO::Scalar', \$text;

    my $ldifout = Net::LDAP::LDIF->new( \*OUT, "r" );

    while ( my $entry = $ldifout->read() ) {
        $entry =
          $self->lat2utf_ldif_entry( $self->removeEmptryAttributes($entry) );
        $entry->changetype("add");
        try( $entry->update($LDAP) ) || print "<pre>\n", $entry->dump(),
          "</pre><br>\n";

    }

    $ldifout->done();
    return 1;
}

sub fixLdif {
    my $self      = shift;
    my $ldif_text = shift;

    #remove more than 2 line breaks and replace them with one line break
    $ldif_text =~ s/\n\n\n*/\n/g;

    #put a line break before dn
    $ldif_text =~ s/dn:/\ndn:/g;

    #replace multiple linebreaks before dn to 2 line breaks
    $ldif_text =~ s/\n\n\n+?dn/\n\ndn/g;

    #remove all leading line breaks
    $ldif_text =~ s/^\n//g;

    #chomp it
    chomp($ldif_text);
    return $ldif_text;
}

sub removeEmptryAttributes {
    my $self  = shift;
    my $entry = shift;
    for ( $entry->attributes() ) {
        if ( defined($entry->get_value($_)) ) {

            #print "$_: ", $entry->get_value($_), "<br>";
        }
        else {
            $entry->delete($_);
            $self->log_event("deleting empty attribute $_ from entry");
        }
    }
    return $entry;

}

sub lat2utf_ldif_entry {

    # this function takes the entry created by LDIF and cleans it
    my $self = shift;

    # get the origional entry
    my $dirty_entry = shift;

    #make a new entry
    my $entry = Net::LDAP::Entry->new();
    $entry->changetype("add");

    #copy the dn
    $entry->dn( $dirty_entry->dn() );

    #temp array to contain values of the attributes
    my @vals = ();
    for ( $dirty_entry->attributes() ) {

        # don't bother if the attribute has no value
        if ( $dirty_entry->get_value($_) ) {
            @vals = ();
            undef @vals;

            #store the value(s) in the array
            @vals = $dirty_entry->get_value($_);
            if ( scalar(@vals) > 1 ) {

                # if more than one value
                # pass an array ref to lat2utf
                $entry->add( $_, $self->lat2utf( $self->as_arrayref(@vals) ) );
            }
            else {

                #if only one value, just pass the first element
                $entry->add( $_, $self->lat2utf( $vals[0] ) );
            }
        }
    }

    # duh
    return $entry;
}

sub getConf {

# look for value in the LDAP tree.
# Note even though vars are defined withing module branches, they must have a unique name.
# example you cannot have a val named "startmethod" both in "dns_vars" and "mail_vars"
    my $self = shift;
    my $var  = shift;
    my $val  =
      $self->getEntryAsHashRef( "ou=conf, $self->{'Config'}->{'ldapBaseDN'}",
        "ispmanVar=$var", [], "sub" );
    return $val->{'ispmanVal'};
}

sub prepareBranchForDN {
    my $self = shift;
    my $dn   = shift;

    my $baseDN = $self->{'Config'}{'ldapBaseDN'};
    $dn     =~ s/\s*,\s*/,/g;
    $baseDN =~ s/\s*,\s*/,/g;

    if ( $self->{'branches'}{$dn} ) {
        return $dn;
    }

    $dn =~ s/$baseDN$//;
    my ( $currBranch, $prevBranch, @branches, @missingBranches ) = ();
    for ( reverse split( /\s*,\s*/, $dn ) ) {
        if ($prevBranch) {
            $currBranch = join ",", ( $_, $prevBranch );
        }
        else {

            # if its the first time, attach the suffix to the dn.
            $currBranch = join ",", ( $_, $baseDN );
        }
        unshift @branches, $currBranch;
        $prevBranch = $currBranch;
    }

    # Start looking for missing branches.
    # Traverse from top to bottom (branch to root), not, from root to branch

  FindMissingBranches: for (@branches) {
        if ( !$self->branchExists($_) ) {
            print "$_ does not exists\n" if $self->{'Config'}->{'debug'} == 3;
            unshift @missingBranches, $_;
        }
        else {

            # leave as soon as one branch is found
            print "$_ exists\nLeaving\n" if $self->{'Config'}->{'debug'} == 3;
            last FindMissingBranches;
        }
    }

    for (@missingBranches) {
        $currBranch = $_;

        # create the missing branches.
        print "Creating missing branch: $_ <br>\n"
          if $self->{'Config'}->{'debug'} == 3;
        $self->addNewEntryWithData( $_, { 'objectclass' => 'ispmanBranch' } );
    }

    $self->{'branches'}{$currBranch}++;
    return $currBranch;
}

1;
__END__

