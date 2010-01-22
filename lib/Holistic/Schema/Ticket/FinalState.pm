package Holistic::Schema::Ticket::FinalState;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Ticket::State';

__PACKAGE__->table('ticket_final_states');

__PACKAGE__->add_columns(
    'state_count',
    { data_type => 'integer', size => '16', is_nullable => 0 },
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
