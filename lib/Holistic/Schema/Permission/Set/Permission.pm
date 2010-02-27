package Holistic::Schema::Permission::Set::Permission;
    
use Moose;
    
extends 'Holistic::Base::DBIx::Class';
        
my $CLASS = __PACKAGE__;
        
$CLASS->table('permission_set_permissions');
$CLASS->add_columns(
    permission_set_pk1  => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => 16,
        is_foreign_key => 1,
    },
    permission_pk1  => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => 16,
        is_foreign_key => 1,
    },
    prohibit  => {
        data_type     => 'TINYINT',
        is_nullable   => 0,
        size          => 1,
        default_value => 0,
    },

);  
    
$CLASS->set_primary_key(qw/permission_set_pk1 permission_pk1/);

$CLASS->belongs_to('permission', 'Holistic::Schema::Permission',
    { 'foreign.pk1' => 'self.permission_pk1' }
);

$CLASS->belongs_to('permission_set', 'Holistic::Schema::Permission::Set',
    { 'foreign.pk1' => 'self.permission_set_pk1' }
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
