package Holistic::Test::Person;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

has 'person' => (
    is => 'rw',
);

sub person_create : Plan(1) {
    my ( $self, $data ) = @_;

    my $person = $self->schema->resultset('Person')->create({
        name  => $data->{name}  || 'J. Shirley',
        token => $data->{ident} || 'jshirley',
        email => $data->{email} || 'jshirley@coldhardcode.com',
    });

    ok( $person, 'created person' );
    $self->person( $person );

    $person->add_to_identities(
        { realm => 'local', id => $person->token, secret => $data->{password} || 'test-script-generated' }
    );

    $person->add_to_identities( { realm => 'twitter', id => $person->token } );
    $person->add_to_identities( { realm => 'irc', id => $person->token } );

    $person->add_to_identities(
        { realm => 'git', id => $person->token . '@foo', secret => 'public key?' }
    );
}

1;
