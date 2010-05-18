package Data::SearchEngine::Holistic::ChangeItem;
use Moose;

extends 'Data::SearchEngine::Item';

has change => (
    is => 'ro',
    isa => 'Holistic::Schema::Ticket::Change',
    handles => [ qw(ticket) ]
);

1;