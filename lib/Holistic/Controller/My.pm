package Holistic::Controller::My;

use Moose;

BEGIN { extends 'Holistic::Base::Controller'; }

sub setup : Chained('.') PathPart('my') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->log->fatal("XX FIX ME, I JUST STUB THE FIRST PERSON XX");
    my $identity = $c->user_exists ? $c->user : $c->model('Schema::Person::Identity')->search({ 'realm' => 'local' }, { prefetch => [ 'person' ] })->first;
    $c->stash->{identity} = $identity;
    $c->stash->{person}   = $identity->person;
}

sub root : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
}


no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

