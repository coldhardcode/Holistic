package Holistic::Controller::Admin::Product::Queue;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'queue' } },
    class      => 'Schema::Product',
    rs_key     => 'queue_rs',
    object_key => 'queue',
    prefetch   => [ 'type' ],
    create_string => 'The queue has been created.',
    update_string => 'The queue has been updated.',
);

sub timemarker : Chained('object_setup') PathPart('') CaptureArgs(0) { }

sub _fetch_rs {
    my ( $self, $c ) = @_;

    $c->stash->{types} = $c->model('Schema::Queue::Type')->search_ordered;
    # XX need a mechanism to sort
    $c->stash->{product}->queues({ }, { order_by => 'name' });
}

sub object_GET {
    my ( $self, $c ) = @_;

    $c->stash->{selected_groups} = {
        map { $_ => $_ }
        $c->stash->{$self->object_key}->group_links
        ->get_column('group_pk1')->all
    };
    $c->log->_dump({ selected_groups => $c->stash->{selected_groups} });
}

sub create_form : Chained('setup') PathPart('create') Args(0) {
    my ( $self, $c ) = @_;

    my $type;

    if ( my $id = $c->req->params->{type_pk1} ) {
        $type = $c->model('Schema::Queue::Type')->find($id);
    }
    $type ||= $c->model('Schema::Queue::Type')->first;
    $c->stash->{type} = $type;

    $c->stash->{queue_rs} = $c->model('Schema::Queue')->search_rs(
        { 
            'product_links.product_pk1' => $c->stash->{product}->id,
            #'me.active'                 => 1,
        },
        {
            prefetch => [ 'product_links' ]
        }
    );
}

sub post_create : Private {
    my ( $self, $c, $data, $object ) = @_;
    $c->log->debug("Adding $object to ". $c->stash->{product});
    $c->stash->{product}->add_to_queues( $object );
}

sub post_update : Private {
    my ( $self, $c, $data, $object ) = @_;

    $object->group_links->delete;
    if ( defined ( my $groups = $data->{groups} ) ) {
        $groups = [ $groups ] unless ref $groups eq 'ARRAY';

        foreach my $group ( @$groups ) {
            $c->log->debug("Setting link to $group");
            $object->group_links->create({ group_pk1 => $group });
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
