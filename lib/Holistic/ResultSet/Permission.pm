package Holistic::ResultSet::Permission;

use Moose;

extends 'Holistic::Base::ResultSet';

use Catalyst::Utils;
use Carp;

sub allow { 
    my ( $self, $permission, %args ) = @_;
    my $scope;
    if ( $args{scope} ) {
        $scope = $args{scope};
    }
    confess "Permissions may only be applied to objects that consume the permissions role (not $scope)"
        unless $scope->meta->does_role('Holistic::Role::Permissions');

    $self->result_source->schema->storage->debug(1);
    my $permission = $self->find_or_create({ 'name' => $permission });
    $scope->add_permission( $permission );
    $self->result_source->schema->storage->debug(0);
   
}

sub prohibit { }

sub prohibit_all { }
sub allow_all { }

sub for { { } }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
