package Holistic::Node;

use Moose;

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has 'tree' => (
    is => 'rw',
    isa => 'Holistic::Tree',
    handles => {
        next_step   => 'next_step',
        add_child   => 'add_child',
        child_count => 'child_count',
        size        => 'size',
        height      => 'height',
        traverse    => 'traverse',
    }
);

has 'tickets' => (
    is      => 'ro',
    isa     => 'ArrayRef[Holistic::Ticket]',
    default => sub { [] },
    lazy    => 1,
    traits  => [ 'Array' ],
    handles => {
        '_add_to_tickets' => 'push',
        'all_tickets'     => 'elements',
        'has_tickets'     => 'count',
        'ticket_count'    => 'count',
        'remove_ticket'   => 'delete',
    },
);

sub add_ticket {
    my ( $self, $ticket ) = @_;

    if ( $self->child_count ) {
        return $self->tree->get_child_at(0)->add_ticket( $ticket );
    }

    # Old step
    my $step = $ticket->step;
    if ( defined $step ) {
        for ( my $i = 0; $i < $step->all_tickets; $i++ ) {
            if ( $ticket->step->tickets->[$i] == $ticket ) {
                $ticket->step->remove_ticket( $i );
                last;
            }
        }
    }
    warn "Setting ticket step to $self\n";
    $ticket->step( $self );
    $self->_add_to_tickets( $ticket );
}

no Moose;
__PACKAGE__->meta->make_immutable;


