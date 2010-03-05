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

sub ticket_create : Plan(28) {
    my ( $self, $data ) = @_;

    my $type_ms = $self->resultset('Queue::Type')->find_or_create({
        name => 'Milestone'
    });

    my $queue;
    if ( $self->meta->does_role('Holistic::Test::Queue') ) {
        $queue = $self->queue;
    }

    $queue ||= $self->resultset('Queue')->find_or_create({
        name  => 'Test Queue',
        token => 'test-suite-queue',
        type  => $type_ms
    });

    if ( $self->meta->does_role('Holistic::Test::Person') ) {
        my $group = $self->group;
        $queue->group_links->create({ group => $group });
        cmp_ok(
            $group->persons->count, '==', $queue->assignable_persons->count,
            'group assignable persons ok'
        );
    } else {
        ok(1, 'skipping group test, no group!');
    }

    my $identity = $data->{identity} ?
        $self->resultset('Person::Identity')->single({ realm => 'local', id => $data->{identity} }) :
        $self->person->identities({ realm => 'local' })->first;

    if ( not defined $identity ) {
        confess "Unable to find identity";
    }

    my $priority = $self->resultset('Ticket::Priority')->find_or_create({
        name => $data->{priority} || 'Urgent'
    });

    my $ticket_type = $self->resultset('Ticket::Type')->find_or_create({
        name => $data->{ticket_type} || 'Task'
    });

    my $milestone = $self->resultset('Queue')->create({
        name        => 'Version 4.5',
        token       => 'version-4.5',
        type        => $type_ms,
        parent_pk1  => $queue->id,
    });

    my $ticket = $self->resultset('Ticket')->create({
        name        => $data->{name} || 'Test Suite Generated Ticket',
        token       => 'test-suite-generated-ticket',
        description => $lorem->paragraphs(2),
        identity    => $identity,
        parent_pk1  => $milestone->id,
        priority    => $priority,
        type        => $ticket_type,
        dt_created  => $data->{dt_created}
    });

    $self->ticket( $ticket );

    is( $ticket->status->name, '@new ticket', 'new ticket status' );

    my $state = $ticket->state;

    cmp_ok( $state->identity_pk1, '==', $identity->pk1, 'proper identity state');
    ok( $state, 'now we have a state' );

    cmp_ok( $state->state_count, '==', 1, 'final state cached' );
    cmp_ok( $ticket->final_state->state_count, '==', 1, 'final state cached' );
    is( $ticket->final_state->priority->name, $priority->name, 'final state priority' );
    cmp_ok( $ticket->final_state->identity_pk1, '==', $identity->pk1, 'final state identity' );
    cmp_ok( $ticket->requestor->pk1, '==', $identity->pk1, 'requestor identity' );
    cmp_ok( $identity->tickets->count, '==', 1, 'ticket count on identity' );
    cmp_ok( $identity->person->tickets->count, '==', 1, 'ticket count on person' );

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
    cmp_ok( $milestone->all_tickets->count, '==', 1, 'ticket count on milestone' );

    my $dt_due = DateTime->now->add( weeks => 1 );
    $queue->due_date( DateTime->now->add( months => 1 ) );
    $ticket->due_date( $dt_due );

    cmp_ok( $queue->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->due_date->dt_marker, '==', $dt_due, 'due date ok');

    ok( ! $ticket->needs_attention, 'ticket doesnt need attention');
    
    my $person = $self->resultset('Person')->create({
        name  => 'Joe',
        token => 'joe',
        email => 'joe@joe.com',
    });
    my $ident = $person->add_to_identities({ realm => 'local', id => 'joe' });
    cmp_ok( $person->needs_attention->count, '==', 0, 'person has no attn tickets' );
    $ticket->needs_attention( $ident );
    cmp_ok( $ticket->needs_attention->pk1, '==', $ident->pk1, 'ticket needs attention');
    cmp_ok( $person->needs_attention->count, '==', 1, 'person->needs_attention' );
    ok( $ticket->clear_attention(0), 'clear attention' );
    cmp_ok( $person->needs_attention->count, '==', 0, 'person has no attn tickets' );
    ok( !$ticket->clear_attention, 'clear attention twice is dumb' );

    cmp_ok( $ticket->state->success, '==', 0, 'ticket is in failure state');

    $ticket->needs_attention( $ident );

    cmp_ok( $queue->all_tickets->search({ 'status.name' => '@ATTENTION' })->count, '==', 1, 'ticket count on queue by status' );

    $ticket->tag(qw/foo bar baz/);

    cmp_ok( $person->needs_attention->count, '==', 1, 'person->needs_attention' );
    $ticket;
}

sub ticket_dependencies : Plan(2) {
    my ( $self, $data ) = @_;

    my $ticket = $self->ticket;

    my $requestor  = $ticket->requestor;
    my @identities = ( $requestor, $requestor, $requestor, $requestor, $requestor );

    for ( 0 .. 4 ) {
        my $new = $self->resultset('Ticket')->create({
            name  => $lorem->words(4),
            token => $lorem->words(4),
            description => $lorem->paragraphs(2),
            identity    => $identities[$_],
            queue       => $ticket->queue,
            priority    => $ticket->priority,
            type        => $ticket->type,
            parent_pk1  => $ticket->parent_pk1
        });
        $ticket->add_to_dependent_links({
            linked_ticket => $new,
            identity_pk1  => $identities[$_]->id,
            type          => $self->resultset('Label')->find_or_create({ name => 'Blocking' }),
        });
        if ( $_ == 0 ) {
            $new->close( $identities[$_] );
        }
    }

    cmp_ok( $ticket->queue->all_tickets, '==', 6, 'ticket count on queue');
    cmp_ok( $ticket->dependencies->count, '==', 5, 'right dependency count');
}

1;
