package Holistic::Controller::Admin::Product::Queue::TimeMarker;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'times' } },
    class      => 'Schema::Product',
    rs_key     => 'time_markers_rs',
    object_key => 'time_marker',
    scope      => 'timemarker',
    create_string => 'The time marker has been created.',
    update_string => 'The time marker has been updated.',
    error_string  => 'There was an error processing your request, please try again.',

);

sub _fetch_rs {
    my ( $self, $c ) = @_;

    $c->stash->{queue}->time_markers;
}

sub prepare_data {
    my ( $self, $c, $data ) = @_;
    my $scope = $self->scope;
    return { $scope => $data };
}

sub post_create : Private {
    my ( $self, $c ) = @_;
    $c->forward('post_action');
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
