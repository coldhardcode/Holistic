package Holistic::ResultSet::Permission;

use Moose;

extends 'Holistic::Base::ResultSet';

use Catalyst::Utils;
use Carp;

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
