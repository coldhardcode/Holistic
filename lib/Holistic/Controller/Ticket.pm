package Holistic::Controller::Ticket;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

=head1 NAME

Holistic::Controller::Register - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub setup : Chained('.') PathPart('register') CaptureArgs(0) {
}

sub object_setup : Chained('setup') PathPart('id') CaptureArgs(1) {
    my ( $self, $c, $pk1 ) = @_;
}

sub object : Chained('object_setup') PathPart('') Args(0) {

}

sub object_alias_setup : Chained('setup') PathPart('-') Args(2) {
    my ( $self, $c, $pk1, $token ) = @_;

    $c->stash->{template} = 'ticket/object.tt';

    $c->forward('object_setup', [ $pk1 ]);
    $c->detach('object');
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
