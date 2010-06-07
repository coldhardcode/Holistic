package Holistic::Schema::Person::Meta;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('person_metas');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_auto_increment => 1 },
    'person_pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_foreign_key => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'value',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'old_value',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'position',
    { data_type => 'integer', is_nullable => 0 }
);

__PACKAGE__->set_primary_key(qw/pk1/);

__PACKAGE__->belongs_to( 'person', 'Holistic::Schema::Person', 'person_pk1' );

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
