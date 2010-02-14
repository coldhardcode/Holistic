package Holistic::Controller::What;

use parent 'Catalyst::Controller';

use Moose;

sub base : Chained('../what') PathPart('what') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

sub default : Chained('base') PathPart('') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'who/default.tt';
}

sub person : Chained('base') PathPart('person') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'person';
    $c->stash->{template} = 'what/object.tt';
}

sub product : Chained('base') PathPart('product') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'product';
    $c->stash->{template} = 'what/object.tt';
}

sub queue : Chained('base') PathPart('queue') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'queue';
    $c->stash->{template} = 'what/object.tt';
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
