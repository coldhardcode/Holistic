package Holistic::Controller::Register;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

=head1 NAME

Holistic::Controller::Register - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub setup : Chained('.') PathPart('register') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    if ( $c->user_exists ) {
        $c->message({
            type => 'attention',
            message => $c->loc("You're already logged in, so you can't register!")
        });
        $c->res->redirect( $c->action_uri( 'Profile', 'object', [ $c->user->person_pk1 ] ), 303 );
        $c->detach;
    }

    if ( my $uri = $c->req->params->{destination} ) {
        $uri = URI->new( $uri );
        $c->log->debug("Got $uri ( " . $uri->host . " eq " . $c->req->uri->host . ")") if $c->debug;
        $uri = undef unless ( $uri->host eq $c->req->uri->host );
        $c->stash->{registration}->{destination} = $uri if defined $uri;
    }
}

sub root : Chained('setup') PathPart('') Args(0) ActionClass('REST') {}
sub root_GET { }
sub root_POST {
    my ( $self, $c ) = @_;
    my $data = $c->req->data || $c->req->params;

    my $person = delete $data->{person};
    my $ident  = delete $data->{ident};
        $ident->{realm} = 'local';
        $ident->{id}    = $person->{email};

    my $known_email = $c->model('Schema::Person')
        ->search({ email => $person->{email} })->first;
    if ( defined $known_email ) {
        $c->message({
            type => 'attention',
            message => $c->loc('The email address [_1] is already registered, did you forget your password?', [ $person->{email} ])
        });
        $c->res->redirect( 
            $c->action_uri( 'Auth', 'forgot_password', 
                { email => $person->{email} } 
            )
        );
        $c->detach;
    }

    my $obj;
    eval {
        ( $obj ) = $c->model('Schema::Person')->register( $person, $ident );
    };
    if ( $@ ) {
        if ( ref $@ eq 'HASH' ) {
            $c->message({
                type    => 'error',
                message => $c->loc('Sorry, please correct the errors below.')
            });
            $c->stash->{form} = $@;
            if ( $c->debug ) {
                $c->log->debug("Rejected registration on user input: ");
                $c->log->_dump( $c->stash->{form} );
            }
            $c->detach;
        } else {
            $c->error("Unknown error in registration: $@");
            die $@;
        }
    }
    if ( $c->authenticate({ id => $ident->{id}, secret => $ident->{secret} }, 'local') ) {
        $c->message( $c->loc("Thanks for registering!") );
        my $dest;
        if ( $c->stash->{registration}->{destination} ) {
            $dest = $c->stash->{registration}->{destination};
        }
        $dest ||= $c->action_uri( 'Profile', 'object', [ $obj->id ] );

        $c->res->redirect($dest, 303);
        $c->detach;
    }
    $c->message({
        type => 'error',
        message => $c->loc('Sorry, there was a problem registering your account.  Please try again.')
    });
}

=head1 AUTHOR

Jay Shirley

=cut

1;
