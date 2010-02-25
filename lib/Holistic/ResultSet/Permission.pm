package Holistic::ResultSet::Permission;

use Moose;

extends 'Holistic::Base::ResultSet';

use Catalyst::Utils;
use Carp;

sub allow { 
    my ( $self, $permission, $object ) = @_;

    confess "Permissions may only be applied to objects that consume the permissions role (not $object)"
        unless $object->meta->does_role('Holistic::Role::Permissions');

    my $permission = $self->find_or_create({ 'name' => $permission });
    $object->add_permission( $permission );
}

sub prohibit     { }
sub prohibit_all { }
sub allow_all    { }

sub for { { } }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
