package Holistic::Person;

use Moose;

has 'name' => (
    is => 'rw',
    isa => 'Str'
);

has 'email' => (
    is => 'rw',
    isa => 'Str'
);

has 'active' => (
    is => 'rw',
    isa => 'Bool',
    default => 1
);

no Moose;
__PACKAGE__->meta->make_immutable;
