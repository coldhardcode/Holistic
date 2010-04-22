package Holistic::Util::Searcher;
use Moose;

use Hash::Merge qw(merge);

has 'attributes' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has 'collection' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'connection' => (
    is => 'ro',
    isa => 'MongoDB::Database',
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

    return $self->connection->get_collection($self->collection)->query($self->query, $self->attributes);
}

sub inflate_results {
    my ($self, $cursor) = @_;

    my @results;
    my $inflator = $self->inflator;
    while(my $obj = $cursor->next) {
        push(@results, $inflator->inflate($obj));
    }

    return \@results;
}

1;