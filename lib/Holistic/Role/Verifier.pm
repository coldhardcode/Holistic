package Holistic::Role::Verifier;

use Moose::Role;

use Data::Manager;

has 'profiles' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1
);

has 'manager' => (
    is  => 'ro',
    isa => 'Data::Manager',
    lazy_build => 1,
    handles => {
        verify => 'verify'
    }
);

sub _build_manager {
    my ( $self ) = @_;

    my $manager = Data::Manager->new;

    foreach my $scope ( keys %{ $self->profiles } ) {
        $manager->set_verifier( $scope, $self->profiles->{$scope} );
    }

    return $manager;
}

no Moose::Role;
1;
