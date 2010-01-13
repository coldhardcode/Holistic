package Holistic::Test::Person;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

sub person_create : Plan(1) {
    ok(1, 'Wee');
}

1;
