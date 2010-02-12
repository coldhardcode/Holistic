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
        $identity = $c->model('Schema::Person::Identity')->search({ 'realm' => 'local' }, { prefetch => [ 'person' ] })->first;
    }

    $c->stash->{identity} = $identity;
    $c->stash->{person}   = $identity->person;
}

sub root : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
}

sub profile : Chained('setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

