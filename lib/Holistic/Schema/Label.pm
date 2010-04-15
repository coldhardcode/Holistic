package Holistic::Schema::Label;

use Moose;

use Carp;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('labels');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
