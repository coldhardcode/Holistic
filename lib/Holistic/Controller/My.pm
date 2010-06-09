package Holistic::Controller::My;

use Moose;

BEGIN { extends 'Holistic::Base::Controller'; }

sub setup : Chained('.') PathPart('my') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    # XX Something like this?
    #$c->forward('/util/permissions_needed', [ 'Ticket Owner' ]);

    my $identity = $c->user_exists ? $c->user : undef;

    unless ( $identity ) {
        $c->log->fatal("XX FIX ME, I JUST STUB THE FIRST PERSON XX");
        # XX Also need pagination...
        $identity = $c->model('Schema::Person::Identity')->search({ 'realm' => 'local' }, { prefetch => [ 'person' ] })->first;
    }

    $c->stash->{identity} = $identity;
    $c->stash->{person}   = $identity->person;
}

sub root : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
}

sub profile : Chained('setup') PathPart('') CaptureArgs(0) { }

sub preferences : Chained('setup') Args(0) ActionClass('REST') { }

sub preferences_GET  { }
sub preferences_POST { 
    my ( $self, $c ) = @_;

    my $data = $c->req->data || $c->req->params;
    $c->stash->{person}->save_metadata( $data );

    if ( $c->req->looks_like_browser ) {
        $c->message($c->loc("Your preferences have been updated"));
        $c->res->redirect($c->uri_for_action('/my/root'));
    }
    elsif ( $c->req->header('x-requested-with') =~ /XMLHttpRequest/ ) {
        $c->stash->{page}->{layout} = 'partial';
        $c->res->body(' ');
    }
}


sub tickets : Chained('setup') Args(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

