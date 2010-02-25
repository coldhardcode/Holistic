package Holistic::Schema::Permission::SetLink;
    
use Moose;
    
extends 'Holistic::Base::DBIx::Class';
        
my $CLASS = __PACKAGE__;
        
$CLASS->table('permission_set_links');
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
);  
    
$CLASS->set_primary_key(qw/permission_set_pk1 permission_pk1/);


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
