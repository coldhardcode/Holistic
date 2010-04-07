package Holistic::Test::Queue;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'queue' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Queue'
);

sub queue_create : Plan(1) {
    my ( $self, $data ) = @_;

    my $type_ms = $self->resultset('Queue::Type')->find_or_create({
        name => 'Milestone'
    });

    my $queue = $self->schema->resultset('Queue')->find_or_create({
        name  => $data->{name} || 'A Q',
        token => $data->{token} || 'a-queue',
        type  => $type_ms,
    });
    $queue->discard_changes;

    ok($queue, 'created queue');
    $self->queue( $queue );

    return $queue;
}

1;
