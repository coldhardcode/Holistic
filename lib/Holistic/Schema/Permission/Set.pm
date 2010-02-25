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
    result_class => {
        data_type   => 'VARCHAR',
        size        => 255,
        is_nullable => 0,
    },
    dt_created => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1 
    }
);  
    
$CLASS->set_primary_key('pk1');

