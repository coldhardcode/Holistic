package Holistic::Schema::Ticket::Type;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Queue::Type';

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

