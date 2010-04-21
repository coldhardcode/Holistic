package Holistic::Util::Searcher;
use Moose;

use Hash::Merge qw(merge);

has 'attributes' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has 'connection' => (
    is => 'ro',
    isa => 'MongoDB::Connection',
    required => 1
);

has 'inflator' => (
    is => 'ro',
    isa => 'Holistic::Util::Inflator',
    required => 1
);

has 'query' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

sub search {
    my ($self, $query, $attrs) = @_;

    if(defined($attrs)) {
        $self->attributes(merge($attrs, $self->attributes));
    }
    if(defined($query)) {
        $self->query(merge($query, $self->query));
    }
}

sub get_results {
    my ($self) = @_;

    return $self->connection->get_database('holistic')->get_collection('tickets')->query($self->query, $self->attributes);
}

1;