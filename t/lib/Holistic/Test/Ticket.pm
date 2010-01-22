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

    my $ticket = $self->schema->resultset('Ticket')->create({
        name => 'Your mom',
        token => 'your-mom'
    });

    $self->ticket( $ticket );

    my $state = $ticket->state;

    ok( !$state, 'no state yet');

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
}

1;
