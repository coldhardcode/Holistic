package Holistic::Controller::Ticket::Comment;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'comment' } },
    class      => 'Schema::Comment',
    rs_key     => 'comment_rs',
    object_key => 'comment',
);

sub _fetch_rs {
    my ( $self, $c ) = @_;
    $c->stash->{ticket}->comments({ }, { prefetch => [ 'person' ] });
}

sub prepare_data {
    my ( $self, $c, $data ) = @_;

    $data->{subject} = '';
    # XX Require login for comments, or anon identity?
    $data->{identity} = $c->user_exists ?
        $c->user->id : $c->model('Schema')->schema->system_identity->id;

    return $data;
}

sub create : Private {
    my ( $self, $c, $data ) = @_;
    my $ticket = $c->stash->{ticket};

    # Always redirect back to the ticket
    $c->res->redirect( $c->uri_for_action('/ticket/object', [ $ticket->id ]) );

    $data = $self->prepare_data( $c, $data );

    my $result = $c->stash->{$self->rs_key}->verify( $data );
    unless ( $result->success ) {
        if ( $c->debug ) {
            $c->log->debug("Validation error:");
            $c->log->_dump({ invalids => [ $result->invalids ], missings => [ $result->missings ]});
        }

        $c->flash->{errors}->{'create'} = $result;
        my @args = ();
        push @args, $c->req->captures if $c->req->captures;
        #push @args, @{ $c->req->args } if $c->req->args;
        $c->log->debug( $c->action );
        $c->log->_dump( \@args );
        $c->detach;
    }

    my %filter =
        map { $_ => $result->get_value($_) }
        grep { defined $result->get_value($_) }
        $result->valids;
    if ( $c->debug ) {
        $c->log->debug("Creating new " . $self->rs_key . " object:");
        $c->log->_dump({ %filter });
    }

    my $object = $c->model('Schema')->schema->txn_do( sub {
        my $comment = $ticket->add_comment(\%filter);
        $c->message({ type => 'success', message => $self->create_string });
        return $comment;
    } );
}

no Moose;
__PACKAGE__->meta->make_immutable;
