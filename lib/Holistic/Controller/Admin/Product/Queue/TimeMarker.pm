package Holistic::Controller::Admin::Product::Queue::TimeMarker;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'times' } },
    class      => 'Schema::Product',
    rs_key     => 'time_markers_rs',
    object_key => 'time_marker',
);

sub _fetch_rs {
    my ( $self, $c ) = @_;

    $c->stash->{queue}->time_markers;
}

sub post_action : Private {
    my ( $self, $c ) = @_;

    $c->res->redirect(
        $c->uri_for_action('/admin/product/queue/object', [
            $c->stash->{product}->id,
            $c->stash->{queue}->id
        ] )
    );
}

sub create_form : Chained('setup') PathPart('create') Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('post_action');
    $c->detach;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
