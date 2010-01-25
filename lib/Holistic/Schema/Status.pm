package Holistic::Schema::Status;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('statuses');

__PACKAGE__->has_many(
    'ticket_states', 'Holistic::Schema::Ticket::State', 'status_pk1'
);

sub tickets {
    my ( $self ) = @_;
    $self->ticket_states(
        { 
        },
        {
            group_by => [ 'me.ticket_pk1' ],
            prefetch => [ 'ticket' ],
            order_by => [ { '-desc' => 'dt_created' } ],
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
