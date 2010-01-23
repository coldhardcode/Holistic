package Holistic::Schema::TimeMarker;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('timemarkers');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'foreign_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
    'rel_source',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
    'dt_marker',
    { data_type => 'datetime', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->has_many(
    'queues', 'Holistic::Schema::Queue',
    {
        'foreign.pk1'        => 'self.foreign_pk1',
        'foreign.rel_source' => 'self.rel_source'
    }
);

__PACKAGE__->has_many(
    'tickets', 'Holistic::Schema::Ticket',
    {
        'foreign.pk1'           => 'self.foreign_pk1',
        'foreign.result_source' => 'self.result_source'
    }
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
