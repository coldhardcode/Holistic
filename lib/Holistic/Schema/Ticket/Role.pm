package Holistic::Schema::Ticket::Role;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('ticket_roles');

__PACKAGE__->has_many(
    'ticket_person', 'Holistic::Schema::Ticket::Person',
    { 'foreign.role_pk1' => 'self.pk1' }
);

__PACKAGE__->many_to_many( 'persons', 'ticket_person' => 'person' );

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
