package Holistic::Controller::Admin::Group;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'group' } },
    class      => 'Schema::Group',
    rs_key     => 'group_rs',
    object_key => 'group',
);

sub management : Chained('setup') Args(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
