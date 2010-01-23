package Holistic::Schema::Ticket::Priority;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('ticket_priorities');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->has_many('tickets', 'Holistic::Schema::Ticket', 'priority_pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);