package Holistic::Schema::Queue;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

#with 'Holistic::Role::Permissions';

__PACKAGE__->load_components(qw/Tree::AdjacencyList DynamicDefault/);

__PACKAGE__->table('queues');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
    'description',
    { data_type => 'text', is_nullable => 1},
    'color',
    { data_type => 'char', size => '6', is_nullable => 0, default_value => '000000' },
    'rel_source',
    { data_type => 'varchar', size => '255', is_nullable => 0,
        dynamic_default_on_create => sub { shift->result_source->name } },
    'token',
    { data_type => 'varchar', size => '255', is_nullable => 0,
        dynamic_default_on_create => sub { my ( $self ) = @_; $self->schema->tokenize( $self->name ) } },
    'identity_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1,
        dynamic_default_on_create => \&_default_system_user },
    'type_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1,
        dynamic_default_on_create => \&_default_type },
    'parent_pk1',
    { data_type => 'integer', size => '16', is_nullable => 1, default_value => undef },
    'dt_created',
    { data_type => 'datetime', set_on_create => 1 },
    'dt_updated',
    { data_type => 'datetime', set_on_create => 1, set_on_update => 1 },
);

__PACKAGE__->set_primary_key('pk1');
__PACKAGE__->parent_column('parent_pk1');

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

__PACKAGE__->belongs_to(
    'identity', 'Holistic::Schema::Person::Identity',
    { 'foreign.pk1' => 'self.identity_pk1' }
);

__PACKAGE__->has_many(
    'time_markers', 'Holistic::Schema::TimeMarker',
    {
        'foreign.foreign_pk1' => 'self.pk1',
        'foreign.rel_source'  => 'self.rel_source'
    }
);

__PACKAGE__->has_many('group_links', __PACKAGE__ . '::Group',
    { 'foreign.foreign_pk1' => 'self.pk1' }
);
__PACKAGE__->many_to_many('groups' => 'group_links' => 'group' );

sub assignable_priorities {
    shift->schema->resultset('Ticket::Priority')->search_rs( @_ );
}

sub assignable_persons {
    my $self = shift;

    $self->groups
        ->search_related('person_links')
        ->search_related('person',
            { 'identities.realm' => 'local' },
            { prefetch => [ 'identities' ] }
        )->search_rs( @_ );
}

__PACKAGE__->has_many('product_links', 'Holistic::Schema::Product::Queue', 'queue_pk1');
__PACKAGE__->many_to_many('products' => 'product_links' => 'product');

sub due_date {
    my ( $self, $date ) = @_;
    my $marker = $self->time_markers({ name => '@due' })->first;
    if ( defined $date ) {
        if ( $marker ) {
            $marker->update({ dt_marker => $date });
        } else {
            $marker = $self
                ->add_to_time_markers({ dt_marker => $date, name => '@due' });
        }
    }

    $marker;
}

sub _default_type {
    my ( $self ) = @_;

    return $self->result_source->schema->resultset('Queue::Type')->find_or_create({ name => 'Queue' })->pk1;
}

sub _default_system_user {
    my ( $self ) = @_;

    return $self->result_source->schema->resultset('Person::Identity')->single({ realm => 'system', id => 'system' })->pk1;
}

sub all_tickets {
    my ( $self ) = @_;

    my $rs = $self->search_related(
        'children',
        { },
        {
            select   => [ 'me.pk1', 'children.pk1', map { "children_$_.pk1" } 2 .. 5 ],
            as       => [ map { "pk$_" } 1 .. 6 ],
            prefetch => [ 
                { 'children' => { 'children' => { 'children' => { 'children' => 'children' } } } }
            ]
        }
    );
    my @pk1s = $self->pk1;
    while ( my $row = $rs->next ) {
        push @pk1s, grep { defined } map { $row->get_column("pk$_") } 1 .. 5;
    }

    $self->result_source->schema->resultset('Ticket')->search_rs(
        { 'me.parent_pk1' => \@pk1s },
        {
            prefetch => {
                'final_state' => [
                    'identity', 'destination_identity', 'status' 
                ],
            },
            group_by => [ 'me.pk1' ]
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
