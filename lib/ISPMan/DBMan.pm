package ISPMan::DBMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Digest::SHA;

require Exporter;

@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  add_database_form
  edit_database_form

  add_database_cgi
  delete_database_cgi
  modify_database_cgi

  add_database
  delete_database
  modify_database

  getDatabases
  getDatabaseInfo
  getDatabaseBranchDN
  getDatabaseDN
  getDatabasesCount
  getAllDatabaseCount
);
$VERSION = '0.01';

#######################################################################
# Display Form Methods

sub add_database_form {
    my $self = shift;
    my $r    = shift;

    my $domain = $r->param("ispmanDomain");

    # check user limit for this domain
    my $domainMaxDatabases =
      $self->getDomainAttribute( $domain, "ispmanMaxDatabases" );

    my $domainDatabaseCount = $self->getDatabasesCount($domain);

    if (   $domainMaxDatabases > 0
        && $domainDatabaseCount >= $domainMaxDatabases )
    {
        $self->{'message'} =
          "Max databases limit exceeded. <br>Your limit is $domainMaxDatabases <br>You cannot create any more databases.";
        print $self->{'message'};
        return;
    }

    my $template = $self->getTemplate("databases/add.tmpl");
    print $template->fill_in( PACKAGE => "ISPMan" );
}

sub edit_database_form {
    my $self = shift;
    my $r    = shift;

    my $dbInfo = $self->getDatabaseInfo( $r->param("ispmanDBName") );

    my $template = $self->getTemplate("databases/edit.tmpl");
    print $template->fill_in(
        PACKAGE => "ISPMan",
        HASH    => { dbInfo => \$dbInfo }
    );
}

#######################################################################
# CGI Methods

sub add_database_cgi {
    my ( $self, $r ) = @_;

    my $domain = $r->param("ispmanDomain");
    my $dbName = $r->param("ispmanDBName");

    # copy data from CGI
    my $dbhash;
    for (
        qw(ispmanDBType ispmanDBName ispmanDBUser ispmanDBPass ispmanDBHost
        ispmanDBAccessFilter ispmanDBPrivilege)
      )
    {
        my $size = scalar( @{ $r->param_fetch($_) } );
        if    ( $size == 1 ) { $dbhash->{$_} = $r->param($_); }
        elsif ( $size > 1 )  { $dbhash->{$_} = $r->param_fetch($_); }
        else                 { }

    }

    # create database
    if ( $self->add_database( $domain, $dbhash ) ) {
        print $self->refreshSignal($domain);
        print "Creation of the database ", $dbName, " scheduled.";
    }
}

sub modify_database_cgi {
    my $self = shift;
    my $r    = shift;

    my $domain = $r->param("ispmanDomain");

    my $dbhash = {};

    for (
        qw(ispmanDBType ispmanDBName ispmanDBUser ispmanDBPass ispmanDBHost
        ispmanDBAccessFilter ispmanDBPrivilege)
      )
    {
        my $size = scalar( @{ $r->param_fetch($_) } );
        if    ( $size == 1 ) { $dbhash->{$_} = $r->param($_); }
        elsif ( $size > 1 )  { $dbhash->{$_} = $r->param_fetch($_); }
        else                 { }

    }

    if ( $self->modify_database( $domain, $r->param("oldDBName"), $dbhash ) ) {
        print $self->refreshSignal($domain);
        print "Modify the database ", $r->param("oldDBName"), " scheduled.";
    }
    else {
        print "Update failed!";
    }
}

sub delete_database_cgi {
    my $self   = shift;
    my $r      = shift;
    my $domain = $r->param('ispmanDomain');
    my $dbName = $r->param('ispmanDBName');

    if ( $self->delete_database( $dbName, $domain ) ) {
        print $self->refreshSignal($domain);
        print "Database $dbName scheduled for deletion";
    }
    else {
        print "Failed to delete database $dbName!";
    }
}

#######################################################################
# Backend Methods

sub add_database {
    my $self   = shift;
    my $domain = shift;
    my $dbhash = shift;

    my $dbName = $dbhash->{'ispmanDBName'};
    my $server = $dbhash->{'ispmanDBHost'};

    $dbhash->{'objectclass'} = "ispmanDatabaseData";

    # treat password
    if (lc($dbhash->{'ispmanDBType'}) eq "mysql") {
       # generate MySQL password hash
       my $digest=Digest::SHA->new->add($dbhash->{'ispmanDBPass'})->digest;
       $dbhash->{'ispmanDBPass'} = "*".uc(Digest::SHA->new->add($digest)->hexdigest);
    }

    # prepare branch
    $self->prepareBranchForDN( $self->getDatabaseBranchDN($domain) );

    my $dn = $self->getDatabaseDN( $dbName, $domain );

    if ( $self->entryExists($dn) ) {
        print $self->refreshSignal($domain);
        print
          "The operation failed. There is already a database with this name.";
        return 0;
    }
    else {
        if ( $self->addNewEntryWithData( $dn, $dbhash ) ) {
            $self->addProcessToHost( $domain, $server, "AddDatabase", join "&",
                map { "$_=" . ((ref $dbhash->{$_} eq "ARRAY")?join(",",@{$dbhash->{$_}}):$dbhash->{$_}) } keys %$dbhash );
            return 1;
        }
    }
}

sub modify_database {
    my $self       = shift;
    my $domain     = shift;
    my $origDbName = shift;
    my $updates    = shift;

    # get old data
    my $dbInfo = $self->getDatabaseInfo($origDbName);

    # build new DB hash so we have definately all variables
    my $dbNew;
    foreach ( keys %$dbInfo ) {
        $dbNew->{$_} = $updates->{$_} || $dbInfo->{$_};
    }

    my $dn = $self->getDatabaseDN( $dbNew->{'ispmanDBName'}, $domain );

    # treat password change
    if ($dbInfo->{'ispmanDBPass'} ne $dbNew->{'ispmanDBPass'} &&
        lc($dbNew->{'ispmanDBType'}) eq "mysql") {
       # generate MySQL password hash
       my $digest=Digest::SHA->new->add($dbNew->{'ispmanDBPass'})->digest;
       $dbNew->{'ispmanDBPass'} = "*".uc(Digest::SHA->new->add($digest)->hexdigest);
    }

    # do we have a move? (ispmanDBName changed)
    if ( $dbInfo->{'ispmanDBName'} ne $dbNew->{'ispmanDBName'} ) {

        # first add the new entry
        if ( $self->addNewEntryWithData( $dn, $dbNew ) ) {

            # add was successful, so lets delete the old entry
            $self->deleteEntry(
                $self->getDatabaseDN( $dbInfo->{'ispmanDBName'}, $domain ) );
        }
        else {
            return 0;    # already exists or failure
        }
    }
    else {
        # just update existing entry
        if ( !$self->updateEntryWithData( $dn, $dbNew ) ) {
            return 0;
        }
    }

    # create update process
    $self->addProcessToHost(
        $domain,
        $dbNew->{'ispmanDBHost'},
        "UpdateDatabase",
        join "&",
        (
            (map { "old_$_=" . ((ref $dbInfo->{$_} eq "ARRAY")?join(",",@{$dbInfo->{$_}}):$dbInfo->{$_}) } keys %$dbInfo),
            (map { "new_$_=" . ((ref $dbNew->{$_} eq "ARRAY")?join(",",@{$dbNew->{$_}}):$dbNew->{$_}) } keys %$dbNew)
        )
    );
}

sub delete_database {
    my $self   = shift;
    my $dbName = shift;
    my $domain = shift;

    my $dbInfo = $self->getDatabaseInfo($dbName);

    my $dn = $self->getDatabaseDN( $dbName, $domain );
    if ( $self->branchExists($dn) ) {

        if ( $self->deleteEntry($dn) ) {
            $self->addProcessToHost(
                $domain,
                $dbInfo->{'ispmanDBHost'},
                "DeleteDatabase",
                join "&",
                map { "$_=" . ((ref $dbInfo->{$_} eq "ARRAY")?join(",",@{$dbInfo->{$_}}):$dbInfo->{$_}) } keys %$dbInfo );
            return 1;
        }
    }
    return 0;
}

sub getDatabases {
    my $self   = shift;
    my $domain = shift;

    my $dbHash = $self->getEntriesAsHashRef(
        $self->getDatabaseBranchDN($domain),
        "objectclass=ispmanDatabaseData",
        ["ispmanDBName"]
    );
    my $dbs;
    for ( keys %$dbHash ) {
        $dbs->{ $dbHash->{$_}{'ispmanDBName'} } = $_;
    }
    return $dbs;

}

sub getDatabaseInfo {
    my $self   = shift;
    my $dbName = shift;

    my $entry = $self->getEntryAsHashRef( $self->getConf("ldapBaseDN"),
        "ispmanDBName=$dbName", '*', "sub" );

    return $entry;
}

sub getDatabaseBranchDN {
    my $self   = shift;
    my $domain = shift;
    return "ou=databases,ispmanDomain=$domain," . $self->getConf('ldapBaseDN');
}

sub getDatabaseDN {
    my $self   = shift;
    my $dbName = shift;
    my $domain = shift;

    return "ispmanDBName=$dbName," . $self->getDatabaseBranchDN($domain);
}

sub getAllDatabaseCount {
    my ($self) = @_;
    return $self->getCount( $self->getConf('ldapBaseDN'),
        "objectclass=ispmanDatabaseData" );
}

sub getDatabasesCount {
    my $self   = shift;
    my $domain = shift;

    return $self->getCount( $self->getDatabaseBranchDN($domain),
        "objectClass=ispmanDatabaseData" );
}
1;

__END__

