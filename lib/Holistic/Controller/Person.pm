package Holistic::Controller::Person;

use Moose;
use Try::Tiny;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'person' } },
    class      => 'Schema::Person',
    rs_key     => 'person_rs',
    object_key => 'person',
    scope      => 'person',
);

sub object_POST { }
sub object_DELETE { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
