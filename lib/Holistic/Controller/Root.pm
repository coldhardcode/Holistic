package Holistic::Controller::Root;
use Moose;
use namespace::autoclean;

use HTTP::BrowserDetect;
use Message::Stack;
use Message::Stack::DataVerifier;
use DBIx::Class::QueryLog;
use DBIx::Class::QueryLog::Analyzer;

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

sub index : Path('') Args(0) {
    my ( $self, $c ) = @_;

    # This will act as the root for now.
    $c->forward('setup');
    $c->req->params->{date_on} = $c->stash->{now}->ymd;
    $c->detach('/calendar/today');
}

sub setup : Chained('.') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash->{now} = DateTime->now;
    $c->stash->{browser_detect} = HTTP::BrowserDetect->new($c->req->user_agent);

    $c->stash->{holistic_version}       = $Holistic::VERSION;
    $c->stash->{context}->{permissions} = {};

    $c->stash->{system}->{identity} =
        $c->model('Schema')->schema->system_identity;
    $c->stash->{system}->{settings} =
        $c->stash->{system}->{identity}->person->metadata;

    if ($c->debug) {
        my $ql = DBIx::Class::QueryLog->new;
        my $schema = $c->model('Schema')->schema;
        $schema->storage->debugobj($ql);
        $schema->storage->debug(1);

        $c->stash->{'querylog'} = $ql;
        my $ana = DBIx::Class::QueryLog::Analyzer->new({ querylog => $ql });
        $c->stash->{'qlanalyzer'} = $ana;
    }

    if ( $c->user_exists ) {
        my $ident = $c->model('Schema::Person::Identity')
            ->search(
                { 'me.pk1' => $c->user->id },
                { prefetch => [ 'person' ] }
            )->single;

        # Vivify the user from external auth (most likely HTTP Auth)
        if ( not defined $ident ) {
            my $person = $c->model('Schema::Person')->create({
                name  => $c->user->ident,
                token => $c->user->ident,
            });
            # We don't need a secret, since it is external.
            $ident = $person->add_to_identities({
                ident => $c->user->id,
                realm => 'local'
            });
            # XX Throw up a notice to complete their profile?
        }
        if ( defined $ident ) {
            $c->user( $ident );
            my $attn_count = $ident->needs_attention->count;
            $c->log->debug("Tickets need attention: $attn_count")
                if $c->debug;
            if ( $attn_count > 0 ) {
                my $msg = $c->loc('NEEDS ATTENTION', [ $attn_count ]);
                $c->message({
                    scope   => 'sidebar',
                    message => qq{<a href="} . $c->uri_for_action('/my/tickets') . qq{">$msg</a>},
                    level   => 'warn'
                });
            }
            my $permissions = $ident->inflate_permissions;
            $c->stash->{context}->{permissions} = $permissions;
        } else {
            $c->log->fatal("Unable to establish identity of the user");
            $c->logout;
        }
    } else {
        # XX this should move into an RS method?
        # $c->model('Schema::Group')->load('anonymous')->permissions;?
        my $group = $c->model('Schema::Group')->search(
            { 'me.name' => 'anonymous' },
            {
                prefetch => [ 
                    { 'permission_set' => 
                        { 'permission_links' => 'permission' } 
                    },
                ]
            }
        )->first;
        if ( defined $group ) {
            $c->stash->{context}->{groups}      = [ $group ];
            $c->stash->{context}->{permissions} = $group->inflate_permissions;
        }
    }

    if ( defined ( my $errors = $c->flash->{errors} ) ) {
        my $stack = $c->stash->{messages} || Message::Stack->new;

        foreach my $scope ( keys %{ $errors } ) {
            $c->stash->{errors}->{$scope} = $errors->{$scope};
            Message::Stack::DataVerifier->parse( $stack, $scope, $errors->{$scope} );
        }
        $c->stash->{stack}      = $stack;
        $c->stash->{messages} ||= $stack;
    }
}

sub admin     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub calendar  : Chained('setup') PathPart('') CaptureArgs(0) { }
sub chart     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub my        : Chained('setup') PathPart('') CaptureArgs(0) { }
sub person    : Chained('setup') PathPart('') CaptureArgs(0) { }
sub queue     : Chained('setup') PathPart('') CaptureArgs(0) { }
sub search    : Chained('setup') PathPart('') CaptureArgs(0) { }
sub ticket    : Chained('setup') PathPart('') CaptureArgs(0) { }
sub util      : Chained('setup') PathPart('') CaptureArgs(0) { }
sub what      : Chained('setup') PathPart('') CaptureArgs(0) { }

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
    $c->response->status(404);
    $c->stash->{template} = 'errors/404.tt';
}

sub guide : Local {
    my ($self, $c) = @_;
    $c->stash->{template} = 'guide.tt';
}

sub milestone : Local {
    my ($self, $c) = @_;

    $c->stash->{template} = 'milestone.tt';
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

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    {
        my $stash_key = 'message_stack';
        my $messagestack = $c->stash->{$stash_key};

        my $data_messages = $c->model('DataManager')->messages;
        if ( $data_messages->has_messages ) {
            if ( $messagestack ) {
                $messagestack->add( $_ ) for @{ $data_messages->messages };
            } else {
                $messagestack = $data_messages;
                $c->stash->{$stash_key} = $messagestack;
            }
        }
    }

}

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
