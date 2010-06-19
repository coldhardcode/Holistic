package Holistic::Schema::Status;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('statuses');

__PACKAGE__->has_many(
    'tickets', 'Holistic::Schema::Ticket', 'status_pk1'
);
__PACKAGE__->has_many(
    'queues', 'Holistic::Schema::Ticket', 'status_pk1'
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
