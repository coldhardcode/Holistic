package Holistic::Schema::Permission::Set;
    
use Moose;
    
extends 'Holistic::Base::DBIx::Class';
        
my $CLASS = __PACKAGE__;
        
$CLASS->table('permission_sets');
$CLASS->add_columns(
    pk1  => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => 16,
        is_auto_increment => 1,
    },
    dt_created => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1 
    }
);  

$CLASS->set_primary_key('pk1');

$CLASS->has_many(
    'objects' => 'Holistic::Schema::Permission::Set::Object',
    { 'foreign.permission_set_pk1' => 'self.pk1' }
);

$CLASS->has_many(
    'permission_links' => 'Holistic::Schema::Permission::Set::Permission',
    { 'foreign.permission_set_pk1' => 'self.pk1' }
);

$CLASS->many_to_many('permissions' => 'permission_links' => 'permission');


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
