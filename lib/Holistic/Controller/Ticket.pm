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

sub post_create : Private {
    my ( $self, $c, $data, $ticket ) = @_;

    $ticket->due_date( $data->{date_due} );
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
