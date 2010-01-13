package Holistic::Schema::DiscussableComment;
    
use Moose;
    
extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('discussable_threads');
$CLASS->add_columns(
    discussable_pk1  => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => 16,
        is_auto_increment => 1,
    },
    comment_pk1 => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => undef,
        is_foreign_key => 1
    },
    dt_created => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1
    }
);
$CLASS->set_primary_key(qw(discussable_pk1 comment_pk1));
$CLASS->add_unique_constraint(
    discussable_comment_discussable_comment => [qw(discussable_pk1 comment_pk1)]
);

$CLASS->belongs_to('comment' => 'Holistic::Schema::Comment', 'comment_pk1');
$CLASS->belongs_to('discussable' => 'Holistic::Schema::Discussable', 'discussable_pk1');
    
1;   
