package Holistic::Controller::Auth;

use parent 'Catalyst::Controller';

use Moose;
use Net::API::RPX;

__PACKAGE__->config(
    rpx_api_key => 'c187ea23302dbfa675dcb100e8859c4d7ae2cbc8'
);

has 'rpx_api_key' => (
    is  => 'rw',
    isa => 'Str',
);

has 'rpx_client' => (
    is  => 'rw',
    isa => 'Net::API::RPX',
    lazy_build => 1,
);

sub _build_rpx_client {
    my ( $self ) = @_;
    Net::API::RPX->new({ api_key => $self->rpx_api_key });
}

sub setup : Chained('.') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    if ( my $uri = $c->req->params->{destination} ) {
        $uri = URI->new( $uri );
        $c->log->debug("Got $uri ( " . $uri->host . " eq " . $c->req->uri->host . ")") if $c->debug;
        $uri = undef unless ( $uri->host eq $c->req->uri->host );
        $c->stash->{login}->{destination} = $uri if defined $uri;
        $c->log->debug("Destination is: " . $c->stash->{login}->{destination})
            if $c->debug;
    }
}

sub disabled : Chained('setup') Args(0) { }

sub login : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->user_exists ) {
        $c->res->redirect($c->uri_for_action('/my/root'), 302);
        $c->detach;
    }

    if ( $c->config->{'Plugin::Authentication'}->{'realms'}->{'local'}->{'credential'}->{'class'} eq 'HTTP' ) {
        if ( $c->user_exists ) {
            $c->res->redirect( $c->uri_for_action('/my/root') );
            $c->detach;
        }
        # We will always auth here, so the user can effectively logout
        $c->authenticate({ realm => 'local' });
    } else {
        if ( $c->req->method eq 'POST' ) {
            $c->forward('do_login');
        }
    }
}

sub http_post_auth : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;

    $c->authenticate({ realm => 'local' });
    if ( $c->user_exists ) {
        $c->res->redirect( $c->uri_for_action('/my/root') );
        $c->detach;
    }
}

sub logout : Chained('setup') Args(0) { 
    my ( $self, $c ) = @_;

    if ( $c->user_exists ) {
        $c->message( $c->loc("You are now logged out.  We'll miss you.") );
    } else {
        $c->message( $c->loc("You're already logged out.  We'll log you out even more.  Feel better?") );
    }

    $c->delete_session;
    $c->logout;

    #$c->res->redirect( $c->uri_for_action( '/auth/login' ) );
    #$c->detach;
}

sub rpx : Chained('setup') PathPart('login/rpx') Args(0) {
    my ( $self, $c ) = @_;

    if ( defined ( my $rpx_token = $c->req->params->{token} ) ) {
        my $user_data = eval { 
            $self->rpx_client->auth_info({ token => $rpx_token }); 
        };
        # Handle internal RPX error
        if ( $@ ) {
            $c->log->error("RPX Error: $@");
            $c->message({
                type => 'error',
                message => $c->loc("Sorry, we weren't able to properly log you in.  Please try again")
            });
            $c->res->redirect( $c->uri_for_action( '/auth/login') );
            $c->detach;
        }
        if ( $c->debug ) {
            $c->log->debug("Got RXP response:");
            $c->log->_dump($user_data);
        }
        if ( defined ( my $profile = $user_data->{profile} ) ) {
            $c->log->debug("Got profile, checking if we have an identity")
                if $c->debug;
            unless ( $c->authenticate({ id => $profile->{identifier}, secret => 'rpx' }) ) {
                $c->log->debug("No identity, creating one now") if $c->debug;

                my $data = {
                    name  => $profile->{displayName},
                    token => $profile->{preferredUsername},
                    email => $profile->{email}
                };
                my $ident_data = {
                    realm => 'rpx',
                    id    => $profile->{identifier},
                    secret => 'rpx', secret_confirm => 'rpx'
                };

                my ( $person, $ident ) = $c->model('Schema::Person')
                    ->register( $data, $ident_data );
            }
            $c->log->debug("Ok, done with RPX: " . $c->stash->{login}->{destination});
            $c->authenticate({ id => $profile->{identifier}, secret => 'rpx' });
        }
        if ( not $c->stash->{login}->{destination} ) {
            $c->stash->{login}->{destination} ||= 
                $c->uri_for_action('/my/profile');
            # Our custom message plugin
            $c->message($c->loc('Thank you for logging in, here is your profile'));
        } else {
            $c->message($c->loc('Thank you for logging in.'));
        }
        $c->res->redirect( $c->stash->{login}->{destination} );
        $c->detach;
    }
    $c->log->info("Invalid call to RPX endpoint, no token specified");
    $c->res->redirect( $c->uri_for_action('/auth/login') );
    $c->detach;
}

sub do_login : Private {
    my ( $self, $c, $data ) = @_;

    $data ||= $c->req->body_params;

    my $email = $data->{ident} || $data->{email} || '';
    $email =~ s/^\s*|\s*$//g;

    if ( $email and $data->{password} ) {
        $c->log->debug("Logging in with: $email") if $c->debug;
        if ( $c->authenticate({ id => $email, secret => $data->{password}, active => 1 })) { 
            $c->user->person->identities({ realm => 'temp' })->delete;
            $c->log->debug("User $email logged in, yeeesir") if $c->debug;
            $c->message( $c->loc("You've logged in, welcome back!") );

            my $uri = $c->stash->{login}->{destination};
            $uri  ||= $c->uri_for_action( '/my/profile' );
            $c->res->redirect( $uri );
            $c->detach;
        } else {
            $c->message({
                type => 'error',
                message => $c->loc("Sorry, couldn't log you in.  Check your username and password and give it another try.")
            });
            $c->res->redirect( $c->uri_for_action( '/auth/login' ), 303 );
            $c->detach;
        }
    }

    unless ( $data->{email} ) {
        $c->message({
            type => 'error',
            message => $c->loc("Please enter your email to continue")
        });
        $c->stash->{template} = 'auth/login.tt';
        $c->detach;
    }

    my $matches = $c->model('Schema::Person')->search(
        {
            -or => [
                { 'email' => $email },
                {
                    -and => [
                        { 'identities.id'    => $email },
                        { 'identities.realm' => 'local' },
                    ]
                }
            ]
        },
        {
            prefetch => [ 'identities' ]
        }
    );
    if ( $matches->count > 0 ) {
        # Generate temporary password and email them
        my $account = $matches
            ->search({ 'identities.realm' => 'local' })->first;
        my $id = $account->identities({ realm => 'local' })->first;
        
        $account->identities({ realm => 'temp' })->delete;

        my ( $temp_pass ) = Crypt::PassGen::passgen( NLETT => 10 );
        $account->identities->create({
            id      => $id->id,
            secret  => $temp_pass,
            realm   => 'temp'
        });
        $c->log->debug("Temp pass for " . $id->id . ": $temp_pass");
        $c->res->redirect( $c->uri_for_action( '/auth/password_sent' ), 303 );
        $c->detach;
        $c->detach;
    } else {
        $c->message({
            class => 'attention',
            message => $c->loc("We could not find the email address &quot;[_1]&quot; in our system.  Please register for a new account!", [ $email ] )

        });
        $c->res->redirect( $c->uri_for_action( '/register/root' ), 303 );
        $c->detach;
    }
}

sub forgot_password : Chained('setup') PathPart('sign-in/reminder') Args(0) ActionClass('REST') { }
sub forgot_password_GET { }
sub forgot_password_POST { 
    my ( $self, $c ) = @_;

    my $data = $c->req->data || $c->req->body_params;
    unless ( defined $data->{email} ) {
        $c->res->redirect( $c->uri_for_action('/auth/forgot_password') );
        $c->detach;
    }

    my $person = $c->model('Schema::Person')->search(
        { 
            'email' => $data->{email},
        },
        {
            prefetch => [ 'identities' ]
        }
    )->first;

    unless ( defined $person ) {
        $c->message({
            type    => 'attention',
            message => $c->loc(q{Invalid email address.})
        });
        $c->res->redirect( $c->uri_for_action('/auth/forgot_password') );
        $c->detach;
    }

    # If the user has some other identity (3rd party)
    my $identities = $person->identities({ realm => { '!=', 'local' } });
    if ( $identities->count ) {
        $c->message({
            type => 'attention',
            message => $c->loc(q{You've also logged in through a 3rd party.  You can login again.})
        });
        $c->res->redirect( $c->action('Auth', 'login_help', { login_methods => [ $identities->get_column('realm')->all ] } ) );
        $c->detach;
    }

    my $r = $c->model('BePolite')->contact( 
        'Forgot Password',
        { 
            name        => $person->name, 
            email       => $person->email,
            login_link  => $c->uri_for_action('/auth/login')
        }
    );
    if ( $r ) {
        $c->message( $c->loc("You can login here with your temporary password that has been emailed.") );
        $c->res->redirect( $c->uri_for_action('/auth/login') );
        $c->detach;
    }
        $c->message({ 
            type => 'error',
            message => $c->loc("Sorry, there was a problem emailing your temporary password.  Please try again.") 
        });
        $c->res->redirect( $c->uri_for_action('/auth/forgot_password') );
        $c->detach;
}

=head1 AUTHOR

Jay Shirley

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;
