package Holistic::Model::Util;

use Moose;

extends 'Catalyst::Model';

sub parse_date {
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
