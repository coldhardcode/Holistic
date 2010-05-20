package Data::SearchEngine::Holistic::Results;
use Moose;

extends 'Data::SearchEngine::Results';

with 'Data::SearchEngine::Results::Faceted';

sub get_sorted_facet {
    my ($self, $fname) = @_;

    my $facet = $self->get_facet($fname);
    return [] unless defined($facet);
    return [ reverse sort { $facet->{$a} <=> $facet->{$b} } keys %{ $self->get_facet($fname) } ];
}

1;