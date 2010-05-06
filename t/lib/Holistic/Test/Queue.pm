package Holistic::Test::Queue;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'queue' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Queue'
);

sub queue_create : Plan(3) {
    my ( $self, $data ) = @_;

    my $type_ms = $self->resultset('Queue::Type')->find_or_create({
        name => 'Release'
    });

    my $queue = $self->schema->resultset('Queue')->find_or_create({
        name  => $data->{name} || 'Version 1.0',
        token => $data->{token} || 'version_1.0',
        type  => $type_ms,
    });
    my $backlog = $queue->add_step({ name => 'Backlog' });
    $queue->add_step({ name => 'Analysis' });
    my $wip = $queue->add_step({ name => 'Work In Progress' });
        my $dev = $wip->add_step({ name => 'Development' });
            my $code = $dev->add_step({ name => 'Code' });
            my $review = $dev->add_step({ name => 'Review' });
        my $test = $wip->add_step({ name => 'Test' });
        $wip->add_step({ name => 'Merge' });

    $queue->add_step({ name => 'Release' });

    $queue->add_step({ name => 'Stalled' });

    ok($queue, 'created queue');
    $self->queue( $queue );

    is($code->next_step->id, $review->id, 'right next step');
    is($review->next_step->id, $test->id, 'right next step escalate');
    is($queue->initial_state->id, $backlog->id, 'right initial state');
    is($queue->size, 10, 'queue is the right height');
    return $queue;
}

1;
