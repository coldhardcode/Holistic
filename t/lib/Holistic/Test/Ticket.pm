package Holistic::Test::Ticket;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'ticket' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Ticket'
);

sub ticket_create : Plan(4) {
    my ( $self ) = @_;

    my $queue;
    if ( $self->meta->does_role('Holistic::Test::Queue') ) {
        $queue = $self->queue;
    }

    $queue ||= $self->resultset('Queue')->find_or_create({
        name => 'A Q',
        token => 'a-queue'
    });

    my $priority = $self->resultset('Ticket::Priority')->find_or_create({
        name => 'Urgent'
    });

    my $type_ms = $self->resultset('Ticket::Type')->find_or_create({
        name => 'Milestone'
    });
    my $type_wu = $self->resultset('Ticket::Type')->find_or_create({
        name => 'Work Unit'
    });
    my $type_t = $self->resultset('Ticket::Type')->find_or_create({
        name => 'Ticket'
    });

    my $milestone = $self->resultset('Queue')->create({
        name        => 'Version 4.5',
        token       => 'version-4.5',
        parent_pk1  => $queue->id,
    });

    my $ticket = $self->resultset('Ticket')->create({
        name        => 'Your mom',
        token       => 'your-mom',
        parent_pk1  => $milestone->id,
        priority    => $priority,
        type        => $type_t,
    });

    $self->ticket( $ticket );

    my $state = $ticket->state;

    ok( !$state, 'no state yet');

    is( $ticket->status->name, 'New', 'new ticket status' );

    $state = $ticket->state;
    ok( $state, 'now we have a state' );
    cmp_ok( $state->state_count, '==', 1, 'final state cached' );
    #cmp_ok( $ticket->final_state->state_count, '==', 1, 'final state cached' );

    my $comment = $ticket->add_comment({
        identity => $self->person->identities({ realm => 'local' })->first,
        subject  => 'Lorem Ipsum',
        body     => 'Bitches' 
    });

    ok( $comment, 'created comment' );
    cmp_ok($ticket->comments->count, '==', 1, 'one comment');

    $comment = $ticket->add_comment({
        identity => $self->person->identities({ realm => 'git' })->first,
        subject  => 'changeset:a2f13fh89',
        body     => 'changeset comments'
    });

    cmp_ok(
        $ticket->comments(
            { 'identity.realm' => 'git' },
            { prefetch => [ 'identity' ] }
        )->count,
        '==', 1, 'one comment scoped by realm'
    );

    cmp_ok( $queue->all_tickets->count, '==', 1, 'ticket count on queue' );
}

1;
