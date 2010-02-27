package Holistic::Schema::Permission::Set::Object;

use Moose;

use Carp;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('permission_set_objects');

__PACKAGE__->add_columns(
    'permission_set_pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'foreign_pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'result_class',
    {
        data_type      => 'VARCHAR',
        is_nullable    => 0,
        size           => 255,
    },
);

__PACKAGE__->set_primary_key(qw/permission_set_pk1 foreign_pk1/);

__PACKAGE__->belongs_to(
    'permission_set' => 'Holistic::Schema::Permission::Set',
    { 'foreign.pk1' => 'self.permission_set_pk1' }
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
