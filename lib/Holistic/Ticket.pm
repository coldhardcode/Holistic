package Holistic::Ticket;
use Moose;

use Holistic::Types qw(TicketPriority TicketType);

has 'date_due' => (
    is => 'rw',
    isa => 'DateTime'
);

has 'description' => (
    is => 'rw',
    isa => 'Str'
);

has 'priority' => (
    is => 'rw',
    isa => TicketPriority,
    default => 'Normal'
);

has 'summary' => (
    is => 'rw',
    isa => 'Str'
);

has 'tags' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] }
);

has 'type' => (
    is => 'rw',
    isa => TicketType,
    default => 'Defect'
);

1;