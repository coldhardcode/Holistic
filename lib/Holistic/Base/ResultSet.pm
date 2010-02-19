package Holistic::Base::ResultSet;

use Moose;

use Data::Verifier;
use Message::Stack;

extends 'DBIx::Class::ResultSet';

sub verify {
    my $self = shift;
    return $self->new_result({})->verify( @_ );
}

sub search_ordered {
    my ( $self, @columns ) = @_;
    @columns = { '-asc' => 'me.name' }
        unless @columns;

    $self->search_rs({}, { order_by => [ @columns ] });
}

1;
