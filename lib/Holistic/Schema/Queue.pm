package Holistic::Schema::Queue;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('queues');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
    'token',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'type_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'parent_pk1',
    { data_type => 'integer', size => '16', default_value => 0 },
    'dt_created',
    { data_type => 'datetime', set_on_create => 1 },
    'dt_updated',
    { data_type => 'datetime', set_on_create => 1, set_on_update => 1 },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->has_many(
    'tickets', 'Holistic::Schema::Ticket', 
    { 'foreign.parent_pk1' => 'self.pk1' }
);

__PACKAGE__->belongs_to(
    'parent', 'Holistic::Schema::Queue',
    { 'foreign.pk1' => 'self.parent_pk1' }
);

__PACKAGE__->belongs_to(
    'type', 'Holistic::Schema::Queue::Type',
    { 'foreign.pk1' => 'self.type_pk1' }
);


around 'insert' => sub {
    my ( $orig, $self, @args ) = @_;

    if ( not $self->type_pk1 ) {
        if ( not $args[0]->{type} and not $args[0]->{type_pk1} ) {
            $self->type_pk1( $self->result_source->schema->resultset('Queue::Type')->find_or_create({ name => 'Queue' })->id );
        }
    }

    $self->$orig(@args);
};

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
