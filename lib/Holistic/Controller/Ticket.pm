package Holistic::Controller::Ticket;

use Moose;
use Try::Tiny;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'ticket' } },
    class      => 'Schema::Ticket',
    rs_key     => 'ticket_rs',
    object_key => 'ticket',
    scope      => 'ticket',
    create_string => 'The ticket has been created.',
    update_string => 'The ticket has been updated.',
    error_string  => 'There was an error processing your ticket, please try again.',
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

sub advance : Chained('object_setup') Args(0) ActionClass('REST') { }
sub advance_POST {
    my ( $self, $c ) = @_;

    try {
        $c->stash->{ticket}->advance;
    } catch {
        $c->message({ type => 'error', message => $c->loc($_) });
    };

    $c->res->redirect($c->uri_for_action('/ticket/object', $c->req->captures));
}

sub tag : Chained('object_setup')  Args(1) ActionClass('REST') { 
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

    if ( $c->user_exists ) {
        $data->{ticket}->{identity} = $c->user->id;
        return $data;
    }

    if ( defined ( my $reporter = $data->{ticket}->{reporter} ) ) {
        my $identity = $c->model('Schema::Person::Identity')->search({ realm => 'local', ident => lc($reporter) })->first;
        if ( defined $identity ) {
            $data->{ticket}->{identity} = $identity->pk1;
        }
    }
    if ( not defined $data->{ticket}->{identity} ) {
        $data->{ticket}->{identity} = $c->model('Schema')->schema->system_identity->id;
    }
    $data;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
