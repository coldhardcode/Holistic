package Holistic::Schema::Queue;

use Moose;

use Carp;
use Scalar::Util 'blessed';

extends 'Holistic::Base::DBIx::Class';

#with 'Holistic::Role::Permissions';
with 'Holistic::Role::Verify';

__PACKAGE__->load_components(qw/
    +Holistic::Base::DBIx::Class::MatPath
    DynamicDefault
/);

__PACKAGE__->table('queues');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'queue_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'traversal_type',
    { data_type => 'integer', size => '16', default_value => 1 },
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
        dynamic_default_on_create => sub {
            my ( $self ) = @_;
            $self->schema->tokenize( $self->name );
        }
    },
    'identity_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1,
        dynamic_default_on_create => \&_default_system_user },
    'type_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1,
        dynamic_default_on_create => \&_default_type },
    'status_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1,
        dynamic_default_on_create => \&_default_status },
    'path',
    { data_type => 'varchar', size => '255', is_nullable => 0,
        dynamic_default_on_create => sub { shift->token } },
    'closed_queue_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1, is_nullable => 1 },
    'stalled_queue_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1, is_nullable => 1 },
    'dt_created',
    { data_type => 'datetime', set_on_create => 1 },
    'dt_updated',
    { data_type => 'datetime', set_on_create => 1, set_on_update => 1 },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->path_column('path');
__PACKAGE__->parent_column('queue_pk1');

# Verification Code
sub _build_verify_scope { 'queue' }
sub _build__verify_profile {
    my ( $self ) = @_;
    return {
        'profile' => {
            'type_pk1' => {
                'required' => 1,
                'type' => 'Int'
            },
            'name' => {
                'required' => 1,
                'type' => 'Str',
                'max_length' => '255',
                'min_length' => 1
            },
            'description' => {
                'required'   => 1,
                'type'       => 'Str',
                'min_length' => 1
            },
        },
        'filters' => [ 'trim' ]
    };
}


__PACKAGE__->has_many(
    'tickets', 'Holistic::Schema::Ticket', 
    { 'foreign.queue_pk1' => 'self.pk1' }
);

__PACKAGE__->belongs_to(
    'stalled_queue', 'Holistic::Schema::Queue',
    { 'foreign.pk1' => 'self.stalled_queue_pk1' }
);

__PACKAGE__->belongs_to(
    'closed_queue', 'Holistic::Schema::Queue',
    { 'foreign.pk1' => 'self.closed_queue_pk1' }
);

__PACKAGE__->belongs_to(
    'type', 'Holistic::Schema::Queue::Type',
    { 'foreign.pk1' => 'self.type_pk1' }
);

__PACKAGE__->belongs_to(
    'status', 'Holistic::Schema::Queue::Status',
    { 'foreign.pk1' => 'self.status_pk1' }
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

has '_next_step' => (
    is   => 'ro',
    isa  => 'CodeRef',
    lazy_build => 1,
);

sub next_step {
    my ( $self, @args ) = @_;
    my $traversal = $self->_next_step;

    $self->$traversal( @args );
}

sub _build__next_step {
    my ( $self ) = @_;
    # Single, Kanban style (every step must be passed through)
    if ( $self->traversal_type == 1 ) {
        return sub {
            my ( $self, $depth ) = @_;
            $depth = 0 if not defined $depth;
            # If we have chidren, always go there.
            if ( $self->direct_children->count ) {
                return $self->direct_children->first->next_step( $depth + 1 );
            } elsif ( $depth ) {
                return $self;
            }

            my $parent = $self->parent;
            return undef unless defined $parent;

            # Our sibling doesn't exist, so we have to start looking up and over
            my $node = $self;
            while ( defined $node ) {
                my $next = $node->next_sibling;
                return $next->next_step( $depth + 1 ) if defined $next;
        
                $node = $node->parent;
            }
            return undef;
        };
    }
    # Multiple options, meaning you can pick any one of the next steps.
    # This has defined behavior: 
    #  1. If I have children, return the list of children.
    #  2. If I don't have children, look at my parents next sibling and 
    #     a) return those children
    #     b) return the next step as a single option.
    # 
    elsif ( $self->traversal_type == 2 ) {
        return sub {
            my ( $self, $depth ) = @_;
            $depth = 0 if not defined $depth;
            # Do we have children?
            if ( $self->direct_children->count > 0 ) {
                return $self->direct_children->all;
            } elsif ( $depth ) {
                return $self;
            }

            my $sibling = $self->next_sibling;
            if ( defined $sibling and $sibling->direct_children->count > 0 ) {
                return $sibling->direct_children->all;
            }

            my $parent = $self->parent;
            return undef if not defined $parent;

            my $aunt = $parent->next_sibling;
            return $aunt->next_step( $depth + 1 ) if defined $aunt;
            #my $sibling = $self->parent->next_sibling;

            # Finally, return the sibling if we got here.
            return $sibling;
        };
    }
}

sub initial_state {
    my ( $self, $depth ) = @_;
    $depth = 0 if not defined $depth;
    
    my $parent = $self->parent;
    if ( $depth == 0 and defined $parent and $parent->id != $self->id ) {
        return $parent->initial_state;
    }
    my $child = $self->direct_children->first;
    if ( defined $child ) {
        return $child->initial_state( $depth + 1 );
    }
    return $self;
}

sub add_step {
    my ( $self, $data ) = @_;

    die "Step must have at least the name\n"
        unless $data->{name};

    $data->{token} ||= $self->schema->tokenize( $data->{name} );
    $data->{path}    = join($self->path_separator, $self->path, $data->{token});
    $data->{queue_pk1}         = $self->id;
    $data->{closed_queue_pk1}  = $self->closed_queue_pk1;
    $data->{stalled_queue_pk1} = $self->stalled_queue_pk1;
    $data->{traversal_type}    = $self->traversal_type;
    my $row = $self->resultset('Queue')->create($data);
    $row->discard_changes;
    return $row;
}

sub is_member {
    my ( $self, $person, $role ) = @_;

    return 0 unless defined $person and blessed( $person );

    my $search = {};
    if ( $person->isa('Holistic::Schema::Person') ) {
        $search->{'person.pk1'} = $person->id;
    }
    elsif ( $person->isa('Holistic::Schema::Person::Identity') ) {
        $search->{'identities.pk1'} = $person->id;
        $search->{'identities.active'} = 1;
    }
    else {
        confess "Invalid call to is_member, require person or identity (not $person)";
    }
    $self->groups(
        $search,
        { join => { 'person_links' => { 'person' => 'identities' } } }
    )->count > 0;
}

sub assignable_priorities {
    shift->schema->resultset('Ticket::Priority')->search_rs( @_ );
}

sub assignable_persons {
    my $self = shift;
    my $top;
    if ( $self->isa('Holistic::Schema::Ticket') ) {
        $top = $self->queue->top_parent;
    } else {
        $top = $self->queue_pk1 ? $self->top_parent : $self;
    }
    $top->groups
        ->search_related('person_links')
        ->search_related('person',
            { 'identities.realm' => 'local' },
            { prefetch => [ 'identities' ] }
        )->search_rs( @_ );
}

sub can_assign_to {
    my ( $self, $person ) = @_;
    $self->assignable_persons->search({ 'person.pk1' => $person->id })->count;
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

    return $self->result_source->schema->resultset('Queue::Type')->find_or_create({ name => 'Queue' })->id;
}

sub _default_status {
    my ( $self ) = @_;

    if ( $self->queue_pk1 ) {
        my $parent = $self->schema->resultset('Queue')->find( $self->queue_pk1 );
        # Return the same status as the parent, everything has to be this way
        # for the time being.
        return $parent->status->id;
    }

    my $status = $self->schema->resultset('Queue::Status')->find({ name => '@open' });
    if ( not defined $status ) {
        $status = $self->schema->resultset('Queue::Status')->create({
            name => '@open'
        });
    }
    return $status->id;
}


sub _default_system_user {
    my ( $self ) = @_;

    return $self->result_source->schema->resultset('Person::Identity')->single({ realm => 'system', ident => 'system' })->pk1;
}

sub all_tickets {
    my ( $self ) = @_;

    my @pk1s = ( $self->pk1, $self->all_children->get_column('me.pk1')->all );

    $self->result_source->schema->resultset('Ticket')->search_rs(
        { 'me.queue_pk1' => \@pk1s },
        {
            prefetch => [
                { 'ticket_persons' => [ 'role', 'person' ] },
                'priority', 'queue', 'time_markers', 'type'
            ],
            group_by => [ 'me.pk1' ],
			order_by => [
				{ '-desc' => 'time_markers.dt_marker' },
				{ '-desc' => 'priority.position' }
			]
        }
    );
}

sub active {
    my ( $self ) = @_;
    my $status = $self->status;
    return $status->accept_tickets && $status->accept_worklog;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
