package Holistic::Base::ResultSet;

use Moose;

use Data::Verifier;
use Message::Stack;

extends 'DBIx::Class::ResultSet';

sub verify {
    my $self = shift;
    return $self->new_result({})->verify( @_ );
}

1;
