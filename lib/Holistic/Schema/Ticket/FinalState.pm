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

# FIXME: I don't know why these aren't inheriting properly.
__PACKAGE__->belongs_to('ticket', 'Holistic::Schema::Ticket', 'ticket_pk1');
__PACKAGE__->belongs_to('status', 'Holistic::Schema::Ticket::Status', 'status_pk1');
__PACKAGE__->belongs_to( 'priority', 'Holistic::Schema::Ticket::Priority', 'priority_pk1');

__PACKAGE__->has_one(
    'identity', 'Holistic::Schema::Person::Identity', 
    { 'foreign.pk1' => 'self.identity_pk1' }
);

__PACKAGE__->belongs_to(
    'destination_identity', 'Holistic::Schema::Person::Identity',
    { 'foreign.pk1' => 'self.identity_pk2' }
);


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
