package Holistic::Test::Ticket;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

use DateTime;
use Text::Lorem;

our $lorem = Text::Lorem->new;

with 'Holistic::Test::Schema'; # We require schema

has 'ticket' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Ticket'
);

sub ticket_create : Plan(19) {
    my ( $self, $data ) = @_;

    my $queue;
    if ( $self->meta->does_role('Holistic::Test::Queue') ) {
        $queue = $self->queue;
    }

    $queue ||= $self->resultset('Queue')->find_or_create({
        name  => 'Test Queue',
        token => 'test-suite-queue'
    });

    my $identity = $data->{identity} ?
        $self->resultset('Person::Identity')->single({ realm => 'local', id => $data->{identity} }) :
        $self->person->identities({ realm => 'local' })->first;

    if ( not defined $identity ) {
        confess "Unable to find identity";
    }

    my $priority = $self->resultset('Ticket::Priority')->find_or_create({
        name => $data->{priority} || 'Urgent'
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
        name        => 'Test Suite Generated Ticket',
        token       => 'test-suite-generated-ticket',
        description => $lorem->paragraphs(2),
        identity    => $identity,
        parent_pk1  => $milestone->id,
        priority    => $priority,
        type        => $type_t,
    });

    $self->ticket( $ticket );

    is( $ticket->status->name, 'NEW TICKET', 'new ticket status' );

    my $state = $ticket->state;

    cmp_ok( $state->identity_pk1, '==', 1, 'proper identity state');
    ok( $state, 'now we have a state' );
    cmp_ok( $state->state_count, '==', 1, 'final state cached' );
    cmp_ok( $ticket->final_state->state_count, '==', 1, 'final state cached' );
    cmp_ok( $ticket->final_state->identity_pk1, '==', 1, 'final state identity' );
    my $comment = $ticket->add_comment({
        identity    => $self->person->identities({ realm => 'local' })->first,
        subject     => 'Lorem Ipsum',
        body        => $lorem->sentences(5),
    });

    ok( $comment, 'created comment' );
    cmp_ok($ticket->comments->count, '==', 1, 'one comment');

    $comment = $ticket->add_comment({
        identity => $self->person->identities({ realm => 'git' })->first,
        subject  => 'changeset:a2f13fh89',
        body     => $lorem->sentences(2),
    });

    cmp_ok(
        $ticket->comments(
            { 'identity.realm' => 'git' },
            { prefetch => [ 'identity' ] }
        )->count,
        '==', 1, 'one comment scoped by realm'
    );

    cmp_ok( $queue->all_tickets->count, '==', 1, 'ticket count on queue' );

    my $dt_due = DateTime->now->add( weeks => 1 );
    $queue->due_date( DateTime->now->add( months => 1 ) );
    $ticket->due_date( $dt_due );

    cmp_ok( $queue->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->due_date->dt_marker, '==', $dt_due, 'due date ok');

    ok( ! $ticket->needs_attention, 'ticket doesnt need attention');
    
    my $schmuck = $self->resultset('Person')->create({
        name  => 'Joe',
        token => 'joe',
        email => 'joe@joe.com',
    });
    my $ident = $schmuck->add_to_identities({ realm => 'local', id => 'joe' });
    $ticket->needs_attention( $ident );
    cmp_ok( $ticket->needs_attention->pk1, '==', $ident->pk1, 'ticket needs attention');
    ok( $ticket->clear_attention(0), 'clear attention' );
    ok( !$ticket->clear_attention, 'clear attention twice is dumb' );

    cmp_ok( $ticket->state->success, '==', 0, 'ticket is in failure state');

    $ticket->needs_attention( $ident );

    cmp_ok( $queue->all_tickets->search({ 'status.name' => 'Attention Required' })->count, '==', 1, 'ticket count on queue' );

    $ticket->tag(qw/foo bar baz/);
}

1;
