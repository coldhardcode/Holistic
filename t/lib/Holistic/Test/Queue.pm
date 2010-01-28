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
    my ( $self ) = @_;

    $queue ||= $self->schema->resultset('Queue')->find_or_create({
        name  => 'A Q',
        token => 'a-queue'
    });

    ok($queue, 'created queue');
    $self->queue( $queue );

    return $queue;
}

1;
