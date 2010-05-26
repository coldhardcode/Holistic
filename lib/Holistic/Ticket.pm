package Holistic::Ticket;
use Moose;

use Holistic::Types qw(TicketPriority TicketType);

use Holistic::Ticket::Assignments;

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

has 'step' => (
    is        => 'rw',
    isa       => 'Holistic::Node',
    predicate => 'has_step',
    handles   => {
        next_step => 'next_step'
    }
);

sub advance {
    my ( $self ) = @_;
    die "Ticket is not part of a process"
        unless $self->has_step;

    my $next = $self->next_step;
    if ( not defined $next ) {
        return undef;
    }
    $next->add_ticket( $self );
}

has 'people' => (
    is      => 'rw',
    isa     => 'Holistic::Ticket::Assignments',
    lazy_build => 1,
    handles => {
        'all_owners' => 'all_owners',
        'add_owners' => 'add_owners',
        'all_cc'     => 'all_cc',
        'add_cc'     => 'add_cc',
        'all_requestors' => 'all_requestors',
        'add_requestor'  => 'add_requestor',
        'all_attention'  => 'all_attention',
        'add_attention'  => 'add_attention',
    }
);

sub _build_people { Holistic::Ticket::Assignments->new }

no Moose;
__PACKAGE__->meta->make_immutable;
