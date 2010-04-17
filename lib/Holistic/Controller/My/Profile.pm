package Holistic::Controller::My::Profile;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'profile' } },
    class      => 'Schema::Person',
    rs_key     => 'person_rs',
    object_key => 'person',
    scope      => 'person',
    update_string => 'Your profile details have been saved.',
    error_string  => 'Error updating your profile, please try again.',
);

after 'setup' => sub {
    my ( $self, $c ) = @_;
    if ( $c->config->{'Plugin::Authentication'}->{'realms'}->{'local'}->{'credential'}->{'class'} eq 'HTTP' ) {
        $c->log->debug("User logged in via HTTP, so can't change password")
            if $c->debug;
        $c->stash->{disable_password_change} = 1;
    } else {
        $c->stash->{context}->{identity} = $c->user->obj;
    }
};

sub _fetch_rs {
    my ( $self, $c ) = @_;
    unless ( $c->user_exists ) {
        $c->res->redirect( $c->uri_for_action('/auth/login') );
        $c->detach;
    }
    $c->model('Schema::Person')->search_rs({ 'me.pk1' => $c->user->person_pk1 });
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
