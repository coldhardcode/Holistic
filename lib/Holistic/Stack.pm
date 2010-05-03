package Holistic::Stack;

use Moose;

use Holistic::Tree;

#extends 'Holistic::Node';

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has 'tree' => (
    is  => 'rw',
    isa => 'Holistic::Tree',
    handles => {
        add_child => 'add_child',
        size      => 'size',
        height    => 'height',
        traverse  => 'traverse',
    },
    lazy_build => 1
);

has 'blocking_step' => (
    is        => 'ro',
    isa       => 'Holistic::Tree',
    predicate => 'has_default_step',
);

has 'default_step' => (
    is        => 'ro',
    isa       => 'Holistic::Tree',
    predicate => 'has_default_step',
);

sub _build_tree { Holistic::Tree->new; }

sub add_ticket {
    my ( $self, $ticket ) = @_;
    die "No processes on this stack, must create process steps first"
        unless $self->tree->child_count;

    # XX
    my $step = $self->has_default_step ?
        $self->has_default_step : $self->tree->get_child_at(0);
    $step ||= $self->tree;

    $step->add_ticket( $ticket );
}

no Moose;
__PACKAGE__->meta->make_immutable;
