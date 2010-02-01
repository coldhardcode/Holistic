package Holistic::Schema::Ticket;

=head1 NAME

Holistic::Schema::Ticket

=head1 MAGNUM OPUS

The Ticket is the core and center of Holistic.  A ticket belongs in a queue,
which has other specific and configurable rules that define certain default
values and other attributes.

=head2 QUEUES AND MILESTONES

A ticket is a subclass of a queue, with additional features.  A queue is
essentially some defined workflow that tickets go through, this can be the
top level group queue, or a subordinate milestone object.

In any case, a ticket has one of these, linked by the C<parent_pk1> column.

=head2 INFORMATIONAL CATEGORIES

The ticket is largely divided into four categories, or contexts, of information.

=over

=item Core Information

The core information of a ticket is simple, and is all the information relating
to the definition of the ticket.  Essentially it should be thought of as
immutable, but that would require people always creating perfect tickets.

Instead, think of it as simply the attributes of a ticket that would not be
altered over time, unless the situation around the ticket has changed.

This is the priority (if you adjust priority of a ticket, it wasn't created properly), severity, component, queue, name, description, etc.

=item State

As a ticket is worked on, it has transitional states.  These transitional
states can happen between two identities, such as a hand-off, or just a marker
pertaining to a single individual.

The States are a rolled up, immutable list of timestamped objects that are
then returned as a final "FinalState" object.  Using the C<state> method
performs the task of rolling this up, saving the cached final state in the
database, and returning the proper thing.

The only way to traverse the state, though, is to iterate through each of the
states.

=item Activity Log

All activity on the ticket that is designed for human consumption, outside of
specific metrics.

The difference between the activity log on a ticket, and the state rollup is
designed to be rolled up to find the fully functional outcome of the ticket.

The activity log is much less glamorous, it is simple the log of all actions
taken.  Typically, an action in the activity log will generate a state, but
a state change does not necessarily generate an activity log.

=item Identities

Identities are people or groups who have a vested interest in the ticket.

Each ticket has a concept of membership, with varying roles based on group
or individual aspects.

=back

=head2 Status

Ticket status is a transitional state, and is calculated by the final state.

Thus, the way to fetch the status is simply C<$ticket->state->status>, but since
this is a common exercise, there is a convenience method C<$ticket->status>.

Status is, however, read-only.  The only method to update the status is by
adding a State object into the state stack.

A simple way of updating the status would be:

 $ticket->add_state({
    identity => $ticket->state->identity,
    status   => $schema->resultset('Status')->single({ name => 'Testing' })
 });

If you add a state, the status will be a continuation of whatever the last
status is.  On the first state, if there is no status set at the time of
creation then the status will be the default for the queue that the ticket
exists in.

=head3 STATUS TRANSITIONS

When status is changed, if there are any rules to define what statuses can
go into others (including reversals) the add_state method will fail with an
exception.

=cut

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Queue';

with 'Holistic::Role::ACL',
     'Holistic::Role::Discussable';

__PACKAGE__->table('tickets');
__PACKAGE__->resultset_class('Holistic::ResultSet::Ticket');

# See Holistic::Schema::Queue for all columns
__PACKAGE__->add_columns(
    'priority_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
);

__PACKAGE__->set_primary_key('pk1');
__PACKAGE__->has_many('states', 'Holistic::Schema::Ticket::State', 'ticket_pk1');

__PACKAGE__->might_have(
    'final_state', 'Holistic::Schema::Ticket::FinalState', 'ticket_pk1',
);

__PACKAGE__->belongs_to(
    'type', 'Holistic::Schema::Ticket::Type',
    { 'foreign.pk1' => 'self.type_pk1' }
);

__PACKAGE__->belongs_to(
    'queue', 'Holistic::Schema::Queue',
    { 'foreign.pk1' => 'self.parent_pk1' }
);

__PACKAGE__->belongs_to(
    'priority', 'Holistic::Schema::Ticket::Priority', 'priority_pk1'
);

__PACKAGE__->has_many(
    'ticket_tags', 'Holistic::Schema::Ticket::Tag',
    { 'foreign.ticket_pk1' => 'self.pk1' }
);
__PACKAGE__->many_to_many('tags', 'ticket_tags', 'tag' );

__PACKAGE__->has_many(
    'dependent_links', 'Holistic::Schema::Ticket::Link',
    { 'foreign.ticket_pk1' => 'self.pk1' }
);
__PACKAGE__->many_to_many('dependencies', 'dependent_links', 'linked_ticket' );

{
    local %ENV;
    $ENV{DBIC_OVERWRITE_HELPER_METHODS_OK} = 1;
    __PACKAGE__->has_many('group_links', 'Holistic::Schema::Ticket::Group', 'ticket_pk1');
    __PACKAGE__->many_to_many('groups' => 'group_links' => 'group' );
}

sub activity { shift->comments(@_); }

sub needs_attention {
    my ( $self, $identity ) = @_;

    my $status = $self->result_source->schema->get_status('Attention Required');
    if ( defined $identity ) {
        my $state = $self->state;
        my $source_id;
        if ( defined $state ) {
            $source_id = $state->identity_pk1;
        } else {
            $source_id = $self->result_source->schema->resultset('Person::Identity')->single({ realm => 'system', id => 'system' })->id;
        }
        $self->add_state({
            identity_pk1 => $source_id,
            identity_pk2 => $identity->pk1,
            status_pk1   => $status->id,
        });
    }
    my $state = $self->state;

    if ( $state and $state->status_pk1 == $status->id ) {
        return $state->destination_identity;
    }
    return undef;
}

sub clear_attention {
    my ( $self, $success ) = @_;

    $success = defined $success && $success ? 1 : 0;

    my $rs = $self->states(
        {},
        { order_by => [ { '-desc' => 'me.pk1' } ], rows => 2 }
    );

    my $status = $self->result_source->schema->get_status('Attention Required');
    my ( $attn_state, $prev_state ) = $rs->all;
    if ( $attn_state->status_pk1 == $status->pk1 ) {
        my %cols = $prev_state->get_columns;
            delete $cols{$_} for qw/dt_created pk1 ticket_pk1/;
        $cols{success} = $success;
        $self->add_state({ %cols });
        return 1;
    }

    return 0;
}

sub initial_state {
    my ( $self ) = @_;

    my $state = $self->states(
        {
            'me.status_pk1' => $self->result_source->schema->get_status('NEW TICKET')->id
        },
        {
            order_by => [ { '-asc' => 'me.dt_created' } ],
            prefetch => [ { 'identity' => 'person' } ] 
        }
    )->first;
    return undef unless defined $state;

    return $state;
}

sub requestor {
    my ( $self ) = @_;

    my $state = $self->initial_state;
    return undef unless defined $state;

    $state->identity;
}

sub owner {
    my ( $self ) = @_;
    my $state =
        $self->states({}, { order_by => [ { '-desc' => 'me.pk1' } ] })->first;
    my $id = $state->identity_pk2 || $state->identity_pk1;
    $self->result_source->schema->resultset('Person::Identity')
        ->search({ 'me.pk1' => $id }, { prefetch => [ 'person' ] })
        ->first;
}

sub status {
    my ( $self ) = @_;
    my $state = $self->state;

    if ( not defined $state ) {
        $state = $self->add_state({
            identity => $self->result_source->schema->resultset('Person::Identity')->single({ realm => 'system', id => 'system' }),
            status => $self->result_source->schema->get_status('NEW TICKET')
        });
    }

    $state->status;
}

sub close {
    my ( $self, $identity ) = @_;

    return $self->add_state({
        identity => $identity,
        status => $self->result_source->schema->get_status('CLOSED')
    });
}

sub add_state {
    my ( $self, $info ) = @_;

    $self->result_source->schema->txn_do(sub {
        my $final = $self->final_state;
        $final->delete if defined $final and $final->in_storage;
        $self->add_to_states($info);
    });
}

sub state {
    my ( $self ) = @_;

    my $final_state = $self->final_state;

    my $rs = $self->states(
        {},
        {
            prefetch => [ 'identity', 'destination_identity' ],
            order_by => [ { '-asc' => 'me.dt_created' } ] 
        }
    );

    my $state_count = $rs->count;
    return undef if $state_count == 0;

    if ( defined $final_state && $final_state->state_count != $state_count ) {
        $final_state->delete if $final_state->in_storage;
        $final_state = undef;
    } elsif ( defined $final_state ) {
        $final_state->discard_changes;
    }
    if ( not defined $final_state ) {
        my %merge;
        my @columns = $rs->result_source->columns;

        my %aggregate_columns;
        my %persistent_columns;
        my %normal_columns;

        foreach my $col_name ( @columns ) {
            my $info = $rs->result_source->column_info( $col_name );
            next if $info->{is_auto_increment};

            $col_name = $info->{accessor} if defined $info->{accessor};

            if ( $info->{persist_state} ) {
                $persistent_columns{ $col_name } = $info->{persistent_state};
            }
            elsif ( $info->{aggregate_state} ) {
                $aggregate_columns{ $col_name } = $info->{aggregate_state};
            }
            else {
                $normal_columns{ $col_name } = $col_name;
            }
        }

        while ( my $row = $rs->next ) {
            foreach my $column ( keys %aggregate_columns ) {
                my $type = $aggregate_columns{$column};
                    $type = 'sum' if int($type) == 1;

                if ( $type eq 'sub' ) {
                    $merge{$column} -= $row->$column;
                } else {
                    $merge{$column} += $row->$column;
                }
            }
            foreach my $column ( keys %persistent_columns ) {
                $merge{$column} ||= $row->$column;
            }
            foreach my $column ( keys %normal_columns ) {
                $merge{$column} = $row->$column;
            }
        }

        $merge{state_count} = $state_count;
        $self->final_state( $self->create_related('final_state', \%merge) );
        $final_state = $self->final_state;
    }
    return $final_state;
}

sub tag {
    my ( $self, @tags ) = @_;

    $self->ticket_tags->delete;

    foreach my $tag ( @tags ) {
        my $tag = $self->result_source->schema->resultset('Tag')->find_or_create({
            name => lc($tag)
        });
        $self->add_to_tags($tag);
    }
}

# ACL Methods
sub action_list {
    return {
        'comment' => [ 'Owner', 'Member', 'Manager' ],
    }
}

sub is_member {
    my ( $self, $person, $role ) = @_;
    return 1;
}

# Verification Code
sub _build__verify_profile {
    my ( $self ) = @_;
    my $rs = $self->schema->resultset('Person::Identity');
    return {
        'profile' => {
            'priority_pk1' => {
                'required' => 1,
                'type' => 'Int'
            },
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
            'identity' => {
                'required'   => 1,
                'type'       => 'Holistic::Schema::Person::Identity',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $rs->find( $_ ); }
                )
            },
        },
        'filters' => [ 'trim' ]
    };
}


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

package Holistic::ResultSet::Ticket;

use Moose;

extends 'Holistic::Base::ResultSet';

around 'create' => sub {
    my ( $orig, $self, $data, @args ) = @_;

    my $schema = $self->result_source->schema;
    my $ident;
    if ( exists $data->{identity} ) {
        $ident = delete $data->{identity};
    }
    # in a txn?
    my $ticket = $self->$orig($data, @args);

    if ( defined $ident ) {
        my $status = $schema->get_status('NEW TICKET');
 
        $ticket->add_state({
            identity_pk1 => $ident->pk1,
            status_pk1   => $status->id,
        });
    }
    $ticket;
};

no Moose;
1;
