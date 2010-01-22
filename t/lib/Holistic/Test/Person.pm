package Holistic::Test::Person;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'person' => (
    is => 'rw',
);

sub person_create : Plan(1) {
    my ( $self ) = @_;

    my $person = $self->schema->resultset('Person')->create({
        name  => 'J. Shirley',
        token => 'jshirley',
        email => 'jshirley@coldhardcode.com',
    });

    ok( $person, 'created person' );
    $self->person( $person );

    $person->add_to_identities(
        { realm => 'local', id => 'jshirley', secret => 'test' }
    );
    $person->add_to_identities(
        { realm => 'git', id => 'jshirley@foo', secret => 'public key?' }
    );
}

1;
