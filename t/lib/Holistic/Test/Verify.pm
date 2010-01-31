package Holistic::Test::Verify;

use Moose::Role;

use Test::More;
use MooseX::MethodAttributes::Role;

with 'Holistic::Test::Schema'; # We require schema

sub ticket_profile : Plan(1) {
    my ( $self ) = @_;

    #use Data::Dumper;
    #diag(Dumper($self->resultset('Ticket')->new_result({})->_verify_profile));
    ok(1);
}

1;
