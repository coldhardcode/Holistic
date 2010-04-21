package Holistic::Ticket;
use Moose;
use MooseX::Storage;

with 'MooseX::Storage::Deferred';

has '_id' => (
    is => 'rw',
    isa => 'Str'
);

has 'summary' => (
    is => 'rw',
    isa => 'Str'
);

has 'description' => (
    is => 'rw',
    isa => 'Str'
);

1;