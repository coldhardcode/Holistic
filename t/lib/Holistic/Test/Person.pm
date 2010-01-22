package Holistic::Test::Person;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

sub person_create : Plan(1) {
    my ( $self ) = @_;
    ok(0, 'I am an asshole');
}

1;
