package Holistic::Controller::Admin::Product::Queue;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'queue' } },
    class      => 'Schema::Product',
    rs_key     => 'queue_rs',
    object_key => 'queue',
    prefetch   => [ 'type' ],
    scope      => 'queue',
    create_string => 'The queue has been created.',
    update_string => 'The queue has been updated.',
    error_string  => 'There was an error processing your request, please try again.',
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
}

sub _create : Private {
    my ( $self, $c, $clean_data ) = @_;

    $c->model('Schema')->schema->txn_do( sub {
        my $token = $c->model('Schema')->schema->tokenize( $clean_data->{name} ); 
        $clean_data->{path} = $token;
        $clean_data->{token} = $token;

        my $queue = $c->stash->{$self->rs_key}->create($clean_data);
        # XX stupid hardcoding for now, this should really be part of
        # create, as a rs method. ->setup_queue?
        my @steps = ();
        foreach my $name ( qw/@new @assigned @active @testing @closed/ ) {
            push @steps, $queue->add_step({
                name => $name
            });
        }
        $queue->update({ closed_queue_pk1 => $steps[-1]->id });

        my $qs = $c->model('Schema::Queue::Status')->find({name => '@closed'});
        if ( not defined $qs ) {
            $qs = $c->model('Schema::Queue::Status')->create({
                name           => '@closed',
                accept_tickets => 0,
                accept_worklog => 0,
            });
        }
        $steps[-1]->update({ status_pk1 => $qs->id });
        # XX End of stupid code.
        
        $c->stash->{product}->add_to_queues( $queue );

        return $queue;
    });
}

sub post_update : Private {
    my ( $self, $c, $data, $object ) = @_;

    $object->group_links->delete;
    $c->log->debug("Checking groups:");
    $c->log->_dump( $data );
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
