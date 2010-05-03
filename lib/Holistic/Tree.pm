package Holistic::Tree;

use Moose;

use Holistic::Node;
use Holistic::Types qw(HolisticNode);

extends 'Forest::Tree';

has 'node' => (
    is      => 'rw',
    isa     => HolisticNode,
    coerce  => 1,
    handles => {
        'ticket_count'  => 'ticket_count',
        'add_ticket'    => 'add_ticket',
        'remove_ticket' => 'remove_ticket',
    },
    trigger => sub {
        my ( $self, $old, $new ) = @_;
        # Clobbering time, XX
        $old->tree( $self ) if defined $old;
        $new->tree( $self ) if defined $new;
    }
);

has '_next_step' => (
    is   => 'ro',
    isa  => 'CodeRef',
    lazy_build => 1,
);

sub next_step {
    my ( $self, @args ) = @_;
    my $traversal = $self->_next_step;

    $self->$traversal( @args );
}

sub _build__next_step {
    return sub {
        my ( $self, $depth ) = @_;
        $depth = 0 if not defined $depth;

        if ( $self->child_count and not $depth ) {
            return $self->get_child_at(0);
        }
        return undef unless $self->has_parent;

        my $next_index = $self->parent->get_child_index( $self ) + 1;
        my $next = $self->parent->get_child_at( $next_index );

        return $next if defined $next;

        # We're at the end, so find the next step on the parent
        $self->parent->next_step( $depth + 1 );
    };
}

no Moose;
__PACKAGE__->meta->make_immutable;
