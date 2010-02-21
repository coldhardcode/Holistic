package Data::SearchEngine::Holistic::Item;
use Moose;

extends 'Data::SearchEngine::Item';

has ticket => (
    is => 'ro',
    isa => 'Holistic::Schema::Ticket',
    handles => [ qw(name owner priority status type) ]
);

1;