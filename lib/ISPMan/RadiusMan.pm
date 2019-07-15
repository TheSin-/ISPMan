
=head1 NAME

RadiusMan - Perl sub module for ISPMan

=head1 SYNOPSIS

	use ISPMan;

	RadiusMan gets automagically included by package ISPMan.

=head1 DESCRIPTION

RadiusMan.pm is a submodule of ISPMan.pm that takes care of radius related stuff.

As a programmer, you should use ISPMan, and not this module directly.

This module exports its public methods in ISPMan's namespace so you can call those
methods directly from an ISPMan object.

=cut

package ISPMan::RadiusMan;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA    = qw(ISPMan Exporter AutoLoader);
@EXPORT = qw(
  getRadiusProfilesBranchDN
  getRadiusProfiles
  getRadiusProfileCN
);

$VERSION = '0.9.7';

sub getRadiusProfilesBranchDN {

=head1 METHODS

=item B<getRadiusProfilesBranchDN>

Helper method returning the Branch holding the Radius Profiles.

usage

use ISPMan;
$ispman=ISPMan->new();

$branch=$ispman->getRadiusProfilesBranchDN();

=cut

    my $self = shift;
    return join( ",", "ou=radiusprofiles", $self->getConf('ldapBaseDN') );
}

sub getRadiusProfiles {

=item B<getRadiusProfiles>

Returns a HashRef containing the available radius profiles

usage

$profiles=$ispman->getRadiusProfiles();

for (keys %$profiles) {
	$profile=$profiles->{$_};
	print $profile->{'cn'};
}

=cut

    my $self = shift;

    $self->{'searchFilter'} = "&(objectclass=radiusprofile)";
    $self->{'searchFilter'} .= "($self->{'filter'})" if ( $self->{'filter'} );

    $self->{'radiusprofiles'} =
      $self->getEntriesAsHashRef( $self->getRadiusProfilesBranchDN(),
        $self->{'searchFilter'} );
    return $self->{'radiusprofiles'};

}

sub getRadiusProfileCN {

=item B<getRadiusProfileCN>

Returns a string containing the CN of a RadiusProfile

usage

$cn=$ispman->getRadiusProfileCN($dn)

=cut

    my $self = shift;
    my $dn   = shift;

    my $profile = $self->getEntryAsHashRef($dn);

    if ( $profile->{'cn'} ) {
        return $profile->{'cn'};
    }

    return "nonexisting";
}

1;

__END__
=cut
