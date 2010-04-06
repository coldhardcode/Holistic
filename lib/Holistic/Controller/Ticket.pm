package Holistic::Controller::Ticket;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'ticket' } },
    class      => 'Schema::Ticket',
    rs_key     => 'ticket_rs',
    object_key => 'ticket',
);

=head1 NAME

Holistic::Controller::Register - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub object_alias_setup : Chained('setup') PathPart('-') Args(2) {
    my ( $self, $c, $pk1, $token ) = @_;

    $c->stash->{template} = 'ticket/object.tt';

    $c->forward('object_setup', [ $pk1 ]);
    $c->detach('object');
}

sub tag : Chained('object_setup') PathPargs(0) Args(1) ActionClass('REST') { 
    my ( $self, $c, $tag_id ) = @_;
    $c->stash->{tag} = $tag_id;
}
sub tag_GET {
    my ( $self, $c ) = @_;

    $c->stash->{page}->{layout} = 'partial';
    $c->stash->{template} = 'ticket/editable-tags.tt';
}

sub tag_POST {
    my ( $self, $c ) = @_;
    my $data = $c->req->data || $c->req->params;

    unless ( $data->{tag} ) {
        $c->log->error('No tag specified');
        return;
    }

    my $ticket = $c->stash->{ $self->object_key };
    my $tag = $c->model('Schema::Tag')->find_or_create({
        name => $data->{tag}
    });
    $ticket->ticket_tags->find_or_create({ tag_pk1 => $tag->id });
    $self->status_ok( $c, 
        entity => [ map { $_->get_columns } $ticket->tags->all ]
    );
}

sub tag_DELETE {
    my ( $self, $c ) = @_;
    my $ticket = $c->stash->{ $self->object_key };
    $ticket->ticket_tags({ tag_pk1 => $c->stash->{tag} })->delete;
    $self->status_ok( $c, 
        entity => [ map { $_->get_columns } $ticket->tags->all ]
    );
}

sub comment : Chained('object_setup') PathPart('') CaptureArgs(0) { }

sub assign : Chained('object_setup') Args(0) ActionClass('REST') { }
sub assign_POST {
    my ( $self, $c ) = @_;

    my $data = $c->req->data || $c->req->params;
    if ( defined $data->{identity_pk1} ) {

    }
}

sub create_form : Chained('setup') PathPart('create') Args(0) {
    my ( $self, $c ) = @_;

    my $rs = $c->model('Schema::Queue')->search({}, { prefetch => [ 'type' ] });
    $c->stash->{queue_rs} = $rs;
    if ( my $id = $c->req->params->{'queue_pk1'} ) {
        my $queue = $rs->search({ 'me.pk1' => $id })->first;
        # XX Check access?
        if ( defined $queue ) {
            $c->stash->{queue} = $queue;
        }
    }
}

sub post_create : Private {
    my ( $self, $c, $data, $ticket ) = @_;

    if ( $data->{due_date} ) {
        # XX Need to parse this and validate
        $ticket->due_date( $data->{due_date} );
    }
    if ( $data->{tags} ) {
        $ticket->tag(map { $_ =~ s/^\s*|\s*//g; $_; } split(/,/, $data->{tags}));
    }
}

sub prepare_data {
    my ( $self, $c, $data ) = @_;

    # XX - we need to get a queue filter to create a ticket under a product and
    #      queue.
    $data->{ticket}->{parent_pk1} = 0;
    if ( defined ( my $reporter = $data->{ticket}->{reporter} ) ) {
        my $identity = $c->model('Schema::Person::Identity')->search({ realm => 'local', id => lc($reporter) })->first;
        if ( defined $identity ) {
            $data->{ticket}->{identity} = $identity->pk1;
            $c->log->debug("We have an identity ($identity) to set...");
        }
    }
    $data->{ticket};
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
