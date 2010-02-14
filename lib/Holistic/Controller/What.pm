package Holistic::Controller::What;

use parent 'Holistic::Base::Controller';

use Moose;

sub setup : Chained('.') PathPart('what') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

sub root : Chained('setup') PathPart('') Args(0) {
    my ($self, $c) = @_;
}

sub person : Chained('setup') PathPart('person') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'person';
    $c->stash->{template} = 'what/object.tt';
}

sub product : Chained('setup') PathPart('product') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'product';
    $c->stash->{template} = 'what/object.tt';
}

sub queue : Chained('setup') PathPart('queue') Args(1) {
    my ($self, $c, $person) = @_;

    $c->stash->{object} = 'queue';
    $c->stash->{template} = 'what/object.tt';
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
