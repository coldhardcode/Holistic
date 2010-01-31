package Holistic::Schema::Product::Queue;

use Moose;

use Carp;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('product_queues');

__PACKAGE__->add_columns(
    'product_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'queue_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
);

__PACKAGE__->set_primary_key(qw/product_pk1 queue_pk1/);

__PACKAGE__->belongs_to('product', 'Holistic::Schema::Product', 'product_pk1');
__PACKAGE__->belongs_to('queue', 'Holistic::Schema::Queue', 'queue_pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
