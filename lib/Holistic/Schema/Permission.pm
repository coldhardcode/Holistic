package Holistic::Schema::Permission;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('permissions');
__PACKAGE__->resultset_class('Holistic::ResultSet::Permission');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
