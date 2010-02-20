package Holistic::Controller::Admin::Product::Queue;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'queue' } },
    class      => 'Schema::Product',
    rs_key     => 'queue_rs',
    object_key => 'queue',
    prefetch   => [ 'type' ]
);

sub timemarker : Chained('object_setup') PathPart('') CaptureArgs(0) { }

sub _fetch_rs {
    my ( $self, $c ) = @_;

    $c->stash->{types} = $c->model('Schema::Queue::Type')->search_ordered;
    $c->stash->{product}->queues;
}

sub create_form : Chained('setup') PathPart('create') Args(0) {
    my ( $self, $c ) = @_;

    my $type;

    if ( my $id = $c->req->params->{type_pk1} ) {
        $type = $c->model('Schema::Queue::Type')->find($id);
    }
    $type ||= $c->model('Schema::Queue::Type')->first;
    $c->stash->{type} = $type;
}

sub post_create : Private {
    my ( $self, $c, $data, $object ) = @_;
    $c->log->debug("Adding $object to ". $c->stash->{product});
    $c->stash->{product}->add_to_queues( $object );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
