package Holistic::Schema::Ticket::Type;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Queue::Type';

__PACKAGE__->table('ticket_types');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

