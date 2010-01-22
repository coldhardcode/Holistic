package Holistic::Test::Ticket;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'ticket' => (
    is  => 'rw',
    isa => 'Holistic::Schema::Ticket'
);

sub ticket_create : Plan(1) {
    my ( $self ) = @_;

    my $ticket = $self->schema->resultset('Ticket')->create({
        name => 'Your mom',
        token => 'your-mom'
    });

    $self->ticket( $ticket );

    my $state = $ticket->state;

    ok( !$state, 'no state yet');
}

1;
