package Holistic::Controller::Root;
use Moose;
use namespace::autoclean;

use Message::Stack;
use Message::Stack::DataVerifier;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Holistic::Controller::Root - Root Controller for Holistic

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
}

sub setup : Chained('.') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->stash->{now} = DateTime->now;

    if ( $c->user_exists ) {
        my $name  = $c->user->id;
        my $ident = $c->model('Schema::Person::Identity')
            ->search(
                { id => $name, realm => 'local' },
                { prefetch => [ 'person' ] }
            )->first;
        # Vivify the user from external auth (most likely HTTP Auth)
        if ( not defined $ident ) {
            my $person = $c->model('Schema::Person')->create({
                name  => $name,
                token => $name,
            });
            $ident = $person->add_to_identities({
                id => $c->user->id,
                realm => 'local'
            });
            # XX Throw up a notice to complete their profile?
        }
        if ( defined $ident ) {
            # Clobbering time.
            $c->user( $ident );
            $c->stash->{now}->set_time_zone( $ident->person->timezone );
        } else {
            $c->log->fatal("Unable to establish identity of the user");
            $c->logout;
        }
    }

    if ( defined ( my $errors = $c->flash->{errors} ) ) {
        my $stack = Message::Stack->new;

        foreach my $scope ( keys %{ $errors } ) {
            $c->stash->{errors}->{$scope} = $errors->{$scope};
            Message::Stack::DataVerifier->parse( $stack, $scope, $errors->{$scope} );
        }
        $c->stash->{stack} = $stack;
    }
}

sub admin     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub calendar  : Chained('setup') PathPart('') CaptureArgs(0) { }
sub chart     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub queue     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub my        : Chained('setup') PathPart('') CaptureArgs(0) { }
sub search    : Chained('setup') PathPart('') CaptureArgs(0) { }
sub ticket    : Chained('setup') PathPart('') CaptureArgs(0) { }
sub what      : Chained('setup') PathPart('') CaptureArgs(0) { }
sub util      : Chained('setup') PathPart('') CaptureArgs(0) { }

sub register : Chained('/') PathPart('') CaptureArgs(0) { }
sub auth     : Chained('/') PathPart('') CaptureArgs(0) { }

=head2 default

Standard 404 error page

=cut

sub createticket : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'createticket.tt';
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub guide : Local {
    my ($self, $c) = @_;
    $c->stash->{template} = 'guide.tt';
}

sub log : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'log.tt';
}

sub milestone : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'milestone.tt';
}

sub roadmap : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'roadmap.tt';
}

sub ticketguide : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'ticket.tt';
}

sub ticketlive : Local {
    my ($self, $c) = @_;

    $c->stash->{ticket} = $c->model('Schema::Ticket')->search({
        token       => 'test-suite-generated-ticket',
    })->first;
    $c->stash->{template} = 'ticket-data.tt';
}

sub todo : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'todo.tt';
}

sub wizard : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'wizard.tt';
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
