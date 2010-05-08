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
        name => '@release'
    });

    my $queue = $self->schema->resultset('Queue')->find_or_create({
        name  => $data->{name} || 'Version 1.0',
        token => $data->{token} || 'version_1.0',
        type  => $type_ms,
    });
    ok($queue, 'created queue');
    $self->queue( $queue );

    my $backlog = $queue->add_step({ name => 'Backlog' });
    my $analysis = $queue->add_step({ name => 'Analysis' });
    my $wip = $queue->add_step({ name => 'Work In Progress' });
        is($wip->parent->id, $queue->id, 'right parentage');
        my $dev = $wip->add_step({ name => 'Development' });
            is($dev->parent->id, $wip->id, 'right parentage');
            my $code = $dev->add_step({ name => 'Code' });
            my $review = $dev->add_step({ name => 'Review' });
        my $test = $wip->add_step({ name => 'Test' });
        my $merge = $wip->add_step({ name => 'Merge' });

    my $release = $queue->add_step({ name => 'Release' });

    my $closed_queue  = $queue->add_step({ name => 'Closed' });
    my $stalled_queue = $queue->add_step({ name => 'Stalled' });
    $queue->closed_queue( $closed_queue );
    $queue->stalled_queue( $stalled_queue );
    $queue->update;
    $queue->discard_changes;

    is($backlog->next_step->id, $analysis->id, 'next step');
    is($analysis->next_step->id, $code->id, 'next step');
    is($code->next_step->id, $review->id, 'next step');
    is($review->next_step->id, $test->id, 'right next step escalate');
    is($test->next_step->id, $merge->id, 'right next step escalate');
    is($merge->next_step->id, $release->id, 'right next step escalate');

    is($queue->initial_state->id, $backlog->id, 'right initial state');

    is($queue->closed_queue->id, $closed_queue->id, 'closed queue');
    is($queue->stalled_queue->id, $stalled_queue->id, 'stalled queue');

    is($queue->size, 11, 'queue is the right height');

    return $queue;
}

1;
