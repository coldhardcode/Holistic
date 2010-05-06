package Holistic::Test::Ticket;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

use DateTime;
use Text::Lorem;

our $lorem = Text::Lorem->new;

with 'Holistic::Test::Schema', # We require schema
     'Holistic::Test::Queue',  # And queue
;

has 'ticket' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Ticket'
);

sub ticket_create : Plan(28) {
    my ( $self, $data ) = @_;

    my $queue = $self->queue;
    if ( not defined $queue ) {
        $queue = $self->run_test('queue_create');
    }

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
        name => $data->{ticket_type} || 'Task',
        color => $data->{ticket_color} || 'ddd'
    });

    my $ticket = $self->resultset('Ticket')->create({
        name        => $data->{name} || 'Test Suite Generated Ticket',
        description => $lorem->paragraphs(2),
        queue_pk1   => $queue->initial_state->id,
        priority    => $priority,
        type        => $ticket_type,
        dt_created  => $data->{dt_created}
    });
    $ticket->requestor( $identity->person );

    $self->ticket( $ticket );

    is( $ticket->status->name, 'Backlog', 'new ticket status' );
    
    cmp_ok( $ticket->requestor->pk1, '==', $identity->person_pk1, 'requestor identity' );
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
        type_pk1 => $self->resultset('Comment::Type')->find_or_create({ name => '@worklog' })->id
    });

    cmp_ok(
        $ticket->comments(
            { 'identity.realm' => 'git' },
            { prefetch => [ 'identity' ] }
        )->count,
        '==', 1, 'one comment scoped by realm'
    );
    cmp_ok( $ticket->worklog->count, '==', 1, 'one worklog entry' );
    cmp_ok( $ticket->activity->count, '==', 1, 'one activity entry' );
    cmp_ok( $ticket->comments->count, '==', 2, 'two comments entry' );
 
    cmp_ok( $queue->all_tickets->count, '==', 1, 'ticket count on queue' );
    #cmp_ok( $milestone->all_tickets->count, '==', 1, 'ticket count on milestone' );

    my $dt_due = DateTime->now->add( weeks => 1 );
    $queue->due_date( DateTime->now->add( months => 1 ) );
    $ticket->due_date( $dt_due );

    cmp_ok( $queue->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->time_markers->count, '==', 1, 'time marker ok');
    cmp_ok( $ticket->due_date->dt_marker, '==', $dt_due, 'due date ok');

    ok( !$ticket->needs_attention->count, 'ticket doesnt need attention');
    
    my $person = $self->resultset('Person')->create({
        name  => 'Joe',
        token => 'joe',
        email => 'joe@joe.com',
    });
    my $ident = $person->add_to_identities({ realm => 'local', ident => 'joe' });
    cmp_ok( $person->needs_attention->count, '==', 0, 'person has no attn tickets' );
    $ticket->needs_attention( $ident );
    cmp_ok( $ticket->needs_attention->first->pk1, '==', $ident->person_pk1, 'ticket needs attention');

    cmp_ok( $person->needs_attention->count, '==', 1, 'person->needs_attention' );
    ok( $ticket->clear_attention(0), 'clear attention' );
    cmp_ok( $person->needs_attention->count, '==', 0, 'person has no attn tickets' );
    $ticket->needs_attention( $ident );

    cmp_ok( $queue->all_tickets->search({ 'ticket_persons.active' => 1, 'role.name' => '@attention' })->count, '==', 1, 'ticket count on queue by status' );

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
            name        => $lorem->words(4),
            description => $lorem->paragraphs(2),
            queue       => $ticket->queue,
            priority    => $ticket->priority,
            type        => $ticket->type,
        });
        $new->requestor( $ticket->requestor );
        $ticket->add_to_dependent_links({
            linked_ticket => $new,
            identity_pk1  => $identities[$_]->id,
            type          => $self->resultset('Label')->find_or_create({ name => 'Blocking' }),
        });
    }

    cmp_ok( $ticket->queue->all_tickets, '==', 6, 'ticket count on queue');
    cmp_ok( $ticket->dependencies->count, '==', 5, 'right dependency count');
}

1;
