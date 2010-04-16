package Holistic::DataManager;

use Moose;

extends 'Data::Manager';

has 'scope_to_resultsource' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    traits   => [ 'Hash' ],
    handles  => {
        resultsource_for_scope => 'get'
    }
);

sub data_for_scope {
    my ( $self, $scope ) = @_;

    my $results = $self->get_results($scope);
    return {
        map  { $_ => $results->get_value($_) }
        grep { defined $results->get_value($_) }
        $results->valids
    };
};

no Moose;
__PACKAGE__->meta->make_immutable;

