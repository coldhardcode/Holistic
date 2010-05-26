package Holistic::Controller::Ticket::Comment;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'comment' } },
    class      => 'Schema::Comment',
    rs_key     => 'comment_rs',
    object_key => 'comment',
    scope      => 'comment',
    update_string => 'The comment has been updated.',
    create_string => 'Your comment has been posted.',
    error_string  => 'There was an error processing your comment, please try again.'
);

sub _fetch_rs {
    my ( $self, $c ) = @_;
    $c->stash->{ticket}->comments({ }, { prefetch => [ 'person' ] });
}

sub prepare_data {
    my ( $self, $c, $data ) = @_;

    $data->{subject} = '';
    # XX Require login for comments, or anon identity?
    $data->{comment}->{identity} = $c->user_exists ?
        $c->user->id : $c->model('Schema')->schema->system_identity->id;

    return $data;
}

sub _create : Private {
    my ( $self, $c, $clean_data ) = @_;

    $c->res->redirect( $c->uri_for_action('/ticket/object', [ $c->stash->{ticket}->id ] ) );
    $c->stash->{ticket}->add_comment($clean_data);
    # Clear attention on a comment.
    $c->stash->{ticket}->clear_attention( $c->user )
        if $c->user_exists;
}

no Moose;
__PACKAGE__->meta->make_immutable;
