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
    permissions => {
        # Just to get to this point in the chain, we require this:
        'setup'         => [ 'TICKET_VIEW', 'TICKET_ADMIN', 'TICKET_CREATE' ],
        # And to create we need admin or create:
        'create_form'   => [ 'TICKET_ADMIN', 'TICKET_CREATE' ],
        'root_POST'     => [ 'TICKET_ADMIN', 'TICKET_CREATE' ],
        # To update a ticket:
        'object_POST'     => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        'attributes_POST' => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        'advance_POST'    => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        # To assign:
        'assign_POST'   => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        # To tag:
        'tag_POST'      => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        'tag_DELETE'    => [ 'TICKET_ADMIN', 'TICKET_MODIFY' ],
        # To comment:
        'comment_POST'  => [ 'TICKET_ADMIN', 'TICKET_MODIFY', 'TICKET_APPEND' ],
    }
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

sub attributes : Chained('object_setup') Args(0) ActionClass('REST') { }
sub attributes_GET {
    my ( $self, $c ) = @_;
    $c->stash->{page}->{layout} = 'partial';
    $c->stash->{template} = 'ticket/nav.tt';
}

sub attributes_POST {
    my ( $self, $c ) = @_;
    my $data = $c->req->data || $c->req->params;

    # XX This needs to be refactored into the API Call.

    my $ticket = $c->stash->{ $self->object_key };

    # Clear attention on the user, since they updated.
    $ticket->clear_attention( $c->user ) if $c->user_exists;

    my $priority = $data->{priority} ?
        $c->model('Schema::Ticket::Priority')->find($data->{priority}) : undef;

    $priority = undef if $priority->id == $ticket->priority_pk1;

    my $owner;
    if ( $data->{owner} ) {
        try {
            $owner = $c->model('Schema::Person')->find( $data->{owner} );
            $owner = undef if $owner->id == $ticket->owner->id;
        } catch {
            # XX This is hacky, I admit.  If $ticket->owner returns undef
            # then it throws an error... we need -?>
            $c->log->debug("Failed setting owner, ticket unowned? $_")
                if $c->debug;
        };
    }

    my $attn;
    if ( $data->{attention} ) {
        $attn = $c->model('Schema::Person')->find( $data->{attention} );
        $attn = undef if $ticket->needs_attention->find( $data->{attention} );
    }
    $ticket->update({ priority => $priority }) if $priority;
    $ticket->owner( $owner ) if defined $owner;
    $ticket->needs_attention( $attn ) if defined $attn;

    my $changeset = time;
    $ticket->add_to_changes({
        changeset => $changeset,
        name => 'owner',
        value => $owner->name,
        identity_pk1 => ( $c->user_exists ? $c->user->id : 1 ), # XX
    }) if defined $owner;
    $ticket->add_to_changes({
        changeset => $changeset,
        name => 'attention',
        value => $attn->name,
        identity_pk1 => ( $c->user_exists ? $c->user->id : 1 ), # XX
    }) if defined $attn;
    $ticket->add_to_changes({
        changeset => $changeset,
        name => 'priority',
        value => $priority->name,
        identity_pk1 => ( $c->user_exists ? $c->user->id : 1 ), # XX
    }) if defined $priority;

    if ( $c->req->looks_like_browser ) {
        $c->message($c->loc("Ticket status has been updated"));
        $c->res->redirect($c->uri_for_action('/ticket/object', [ $ticket->id ]));
    }
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

    my $tag = $data->{tag};
    $tag =~ s/^\s*|\s*$//g;


    my $ticket = $c->stash->{ $self->object_key };
    my $obj = $c->model('Schema::Tag')->find_or_create({
        name => $tag
    });
    $ticket->ticket_tags->find_or_create({ tag_pk1 => $obj->id });
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

    my $rs = $c->model('Schema::Queue')->search({ 'me.queue_pk1' => 0 }, { prefetch => [ 'type' ], order_by => [ 'me.name' ] });
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

    if ( $data->{'ticket.due_date'} ) {
        # XX Need to parse this and validate
        $ticket->due_date( $data->{'ticket.due_date'} );
    }
    $ticket->add_to_changes({
        name => 'created',
        identity_pk1 => ( $c->user_exists ?
            $c->user->id : $ticket->owner->id ),
        value => ''
    });
    if ( $data->{'ticket.tags'} ) {
        $ticket->tag(map { $_ =~ s/^\s*|\s*//g; $_; } split(/,/, $data->{'ticket.tags'}));
    }
}

sub prepare_data {
    my ( $self, $c, $data ) = @_;

    # XX We find the first step, this should probably be significantly cleaner
    $data->{ticket}->{queue_pk1} = $c->model('Schema::Queue')
        ->find($data->{ticket}->{queue_pk1})->initial_state->id;

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

    return $data;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
