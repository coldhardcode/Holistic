package Data::SearchEngine::Holistic::Results;
use Moose;

extends 'Data::SearchEngine::Results';

with 'Data::SearchEngine::Results::Faceted';

sub get_sorted_facet {
    my ($self, $name) = @_;

    my $facet = $self->facets->{$name};

    return [ reverse sort { $facet->{$a} cmp $facet->{$b} } keys %{ $facet } ];
}

1;