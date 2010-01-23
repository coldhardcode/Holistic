package Holistic::Schema::Ticket::Link;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('ticket_links');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'ticket_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'ticket_pk2',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'identity_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'type',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
    'dt_created',
    { data_type => 'datetime', set_on_create => 1 },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->belongs_to('ticket', 'Holistic::Schema::Ticket', 'ticket_pk1');
__PACKAGE__->belongs_to('linked_ticket', 'Holistic::Schema::Ticket', 'ticket_pk2');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
