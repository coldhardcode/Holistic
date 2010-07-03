package Holistic::Schema::Ticket;

=head1 NAME

Holistic::Schema::Ticket

=head1 MAGNUM OPUS

The Ticket is the core and center of Holistic.  A ticket belongs in a queue,
which has other specific and configurable rules that define certain default
values and other attributes.

=head2 QUEUES AND MILESTONES

A ticket belongs to a L<Holistic::Schema::Queue> instance, which is a
materialized tree.

The visual is similar to a Kanban board:

 +----------------------------------------------------------------------------+
 |                                 $Project                                   |
 +-----------+-----------+----------------------------------------------------+
 |  Backlog  | Analyasis |   Work In Progress                |     Release    |
 +-----------+-----------+-------------+---------------------+----------------+
 |           |           | Development |   Test   |   Merge  |     Ticket     |
 |           |  Ticket   +-------------+----------+----------+                |
 |  Ticket   |  Ticket   |   Ticket    |  Ticket  |          |                |
 |           |           |             |          |          |                |
 +-----------+-----------+-------------+----------+----------+----------------+

The ticket state is simply the closest queue_pk1 node, which is the active
functional state of the ticket.

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
use Scalar::Util 'blessed';
use Try::Tiny;

extends 'Holistic::Schema::Queue';

with 'Holistic::Role::Discussable',
     'Holistic::Role::Verify';

__PACKAGE__->table('tickets');

# See Holistic::Schema::Queue for base columns
__PACKAGE__->add_columns(
    'queue_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'last_queue_pk1',
    { data_type => 'integer', size => '16', is_nullable => 1, is_foreign_key => 1 },
    'priority_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
);
__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->belongs_to(
    'priority', 'Holistic::Schema::Ticket::Priority', 
    { 'foreign.pk1' => 'self.priority_pk1' }
);

__PACKAGE__->belongs_to(
    'queue', 'Holistic::Schema::Queue', 
    { 'foreign.pk1' => 'self.queue_pk1' }
);

__PACKAGE__->belongs_to(
    'last_queue', 'Holistic::Schema::Queue', 
    { 'foreign.pk1' => 'self.last_queue_pk1' }
);

__PACKAGE__->has_many(
    'time_markers', 'Holistic::Schema::TimeMarker',
    {
        'foreign.foreign_pk1' => 'self.pk1',
        'foreign.rel_source'  => 'self.rel_source'
    }
);

# Convenience
sub status { shift->queue(@_) }

__PACKAGE__->has_many(
    'ticket_meta', 'Holistic::Schema::Ticket::Meta', 'ticket_pk1'
);

__PACKAGE__->has_many(
    'changes', 'Holistic::Schema::Ticket::Change',
    { 'foreign.ticket_pk1' => 'self.pk1' }
);

sub get_metadata {
    my ( $self ) = @_;
    return { map { $_->name => $_->value } $self->ticket_meta->all };
}

__PACKAGE__->belongs_to(
    'type', 'Holistic::Schema::Ticket::Type',
    { 'foreign.pk1' => 'self.type_pk1' }
);

__PACKAGE__->belongs_to(
    'status', 'Holistic::Schema::Status',
    { 'foreign.pk1' => 'self.status_pk1' }
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

__PACKAGE__->has_many(
    'ticket_persons', 'Holistic::Schema::Ticket::Person',
    { 'foreign.ticket_pk1' => 'self.pk1' }
);

sub _get_person_rs_with_role {
    my ( $self, $role ) = @_;
    die "Unable to add_person without a role\n"
        unless defined $role;

    my $role_obj = blessed($role) ?
        $role :
        $self->resultset('Ticket::Role')->find_or_create({ name => $role });

    $self->ticket_persons(
        { 'role.pk1' => $role_obj->id, 'me.active' => 1 },
        { prefetch => [ 'person', 'role' ] }
    )->search_rs;
}

sub _create_person_with_role {
    my ( $self, $person, $role ) = @_;
    die "Unable to add_person without a role\n"
        unless defined $role;

    my $role_obj = blessed($role) ?
        $role :
        $self->resultset('Ticket::Role')->find_or_create({ name => $role });

    my $person_pk1 = $person->isa('Holistic::Schema::Person') ?
        $person->id : $person->person_pk1;
    $self->ticket_persons->create({
        person_pk1 => $person_pk1,
        role_pk1   => $role_obj->id,
        active     => 1
    });
}

sub add_person {
    my ( $self, $person, $role ) = @_;

    $self->_create_person_with_role( $person, $role );
}

sub set_attention {
    my ( $self, $person ) = @_;
    $self->needs_attention( $person );
    
    return $person->name;
}


sub needs_attention {
    my ( $self, $identity ) = @_;

    my $rs = $self->_get_person_rs_with_role('@attention');

    if ( defined $identity ) {
        $self->_create_person_with_role( $identity, '@attention' );
    }
    return $rs->search_related_rs('person', {}, { group_by => 'person.pk1' } );
}

sub clear_attention {
    my ( $self, $success ) = @_;

    my $rs = $self->_get_person_rs_with_role('@attention');
    $rs->update_all({ 'active' => 0 });

    return 1;
}

# there can only be one requestor
sub requestor {
    my ( $self, $person ) = @_;

    if ( defined $person ) {
        $self->_create_person_with_role( $person, '@requestor' );
    }

    my $link = $self->_get_person_rs_with_role('@requestor')->first;
    return defined $link ? $link->person : undef;
}

sub owner {
    my ( $self, $person ) = @_;

    my $link = $self->_get_person_rs_with_role('@owner')->first;
    if ( $person and ( not $link or ( $link and $link->person_pk1 != $person->id ) ) ) {
        my $old = $link->person if defined $link;
        $link->delete if defined $link;
        $link = $self->_create_person_with_role( $person, '@owner' );
    }
    return defined $link ? $link->person : undef;
}


sub worklog {
    my ( $self ) = @_;
    $self
        ->comments({ 'type.name' => '@worklog' }, { prefetch => [ 'type' ] })
        ->search_rs;
}

sub activity {
    my ( $self ) = @_;
    $self
        ->comments(
            { 'type.name' => { '!=', '@worklog' } }, { prefetch => [ 'type' ] }
        )->search_rs;
}

sub all_comments {
    my ( $self ) = @_;
    $self
        ->comments(
            { 'type.name' => { '!=', '@worklog' } }, { prefetch => [ 'type' ] }
        )->search_rs;
}

sub set_priority {
    my ( $self, $priority ) = @_;
    unless ( blessed $priority ) {
        $priority = $self->schema->resultset('Ticket::Priority')->find({ name => $priority });
    }
    confess "Priority specified isn't found\n" unless defined $priority;
    $self->priority( $priority );
}

sub set_status {
    my ( $self, $status ) = @_;
    unless ( blessed $status ) {
        $status = $self->schema->resultset('Status')->find({ name => $status });
    }
    confess "Ticket status specified isn't found\n" unless defined $status;
    $self->status( $status );
}

sub set_tag {
    shift->tag( @{$_[0]} );
}

sub tag {
    my ( $self, @tags ) = @_;

    $self->ticket_tags->delete;

    my @valid_tags = ();
    foreach my $tag ( @tags ) {
        my $results = $self->schema->data_manager
            ->verify( 'tag', { name => $tag } );
        next unless $results->success;

        my $tag = $self->result_source->schema->resultset('Tag')
            ->find_or_create({ name => $results->get_value('name') });
        $self->add_to_tags($tag);
        push @valid_tags, $tag->name;
    }
    return @valid_tags;
}

sub next_step {
    return shift->queue->next_step;
}

sub advance {
    my ( $self, $opt, $args ) = @_;

    my $user  = $args->{user};
    my $queue = $self->queue;
    my @steps = $queue->next_step;
    die "Can't advance ticket, no steps defined\n"
        unless defined $steps[0];
    my $step;
    if ( $opt ) {
        ( $step ) = grep { $_->name eq $opt } @steps;
        # Invalid step, need to figure out proper action.
        # XX die here?
        $opt = 0 if not defined $step;
    }
    $step ||= $steps[ int($opt) ];
    if ( not defined $step ) {
        die "Unable to advance ticket, no further steps\n";
    }

    if ( not defined $user ) {
        $user = $self->schema->system_identity;
    }
    elsif ( $user and $user->isa('Holistic::Schema::Person') ) {
        $user = $user->identities({ realm => 'local', active => 1 })->first;
    }

    my $change = $self->add_to_changes({
        name            =>
            ( $step->id == $queue->closed_queue_pk1 ? 'closed' : 'advanced' ),
        value           => $step->name,
        old_value       => $queue->name,
        identity_pk1    => $user->id
    });
 
    $self->update({queue_pk1 => $step->id, last_queue_pk1 => $self->queue_pk1});

    return $change;
}

sub modify {
    my ( $self, @args ) = @_;
    if ( $args[0] and ref $args[0] eq 'HASH' ) {
        $self->_modify( $args[0] );
    } elsif ( @args == 1 ) {
        $self->_modify({ $args[0] => undef });
    } elsif ( @args % 2 == 0 and @args > 0 ) {
        $self->_modify({ @args });
    } else {
        croak "Invalid call to \$ticket->modify, pass in a hash ref or single action\n";
    }
}

sub _modify {
    my ( $self, $args ) = @_;
    croak "Invalid call to \$ticket->modify private method, must pass a hash ref\n" unless defined $args and ref $args eq 'HASH';

    # Clear the Data::Manager object.  Ideally, *each* transaction should have
    # its own Data::Manager object, but we'll do it here by hand and just
    # pretend it's good enough for now.
    # XX, this won't work in context, because then we lose what Catalyst::Model
    # sends us... so, have to clear this by hand in what you use, which is
    # lame to have to do:
    # $ticket->schema->clear_data_manager;
    # $ticket->modify(...);
    # But... fuck it!
    #$self->schema->clear_data_manager;

    my $modify_txn = sub {
        my @errors  = ();
        my @changes = ();
        my @saved_changes = ();
        my $system_user = $self->schema->system_identity;

        foreach my $arg ( keys %$args ) {
            my $method;
            $method ||= $self->can("set_$arg");
            $method ||= $self->can("$arg");

            next unless defined $method;
            try {
                # If the method fails, it will either just throw a simple
                # error or a Data::Verifier::Results object that we'll
                # mix into our Data::Manager object.
                my $value = $method->( $self, $args->{$arg}, $args );

                if ( blessed $value and $value->isa('Holistic::Schema::Ticket::Change') ) {
                    push @saved_changes, $value;
                } else {
                    if ( blessed $value ) {
                        if ( $value->can('changelog_string') ) {
                            $value = $value->changelog_string;
                        }
                        elsif ($value->can('name') ) {
                            $value = $value->name;
                        }
                    }
                    push @changes, {
                        name         => $arg,
                        value        => $value || $args->{$arg},
                        identity_pk1 => ( $args->{user} ? $args->{user}->id : $system_user->id )
                    };
                }
            } catch {
                # This isn't writing to $schema->data_manager, so we 
                # will manually put things in here.
                if ( ref $_ eq 'Data::Verifier::Results' ) {
                    warn "\n\n** Setting verifier results for $arg: $_\n\n";
                    $self->schema->data_manager->set_results($arg, $_);
                } else {
                    carp $_;
                }
                push @errors, $arg;
            };
        }
        # We've recorded changes, so now record them to the DB
        if ( @changes or @saved_changes ) {
            use Digest::MD5 'md5_hex';
            # The first is to get the signature, which is the timestamp
            # and then the name/value of each change.  This lets you
            # validate that the change is not tampered with... you know,
            # in case you care.  I sure as hell don't, but you may.
            my $changeset = md5_hex(
                join('', time,
                    ( map { ( $_->{name}, $_->{value} ) } @changes ),
                    ( map { ( $_->name, $_->value ) } @saved_changes )
                )
            );
            foreach my $change ( @changes ) {
                $change->{changeset} = $changeset;
                $self->add_to_changes( $change );
            }
            # And lets clobber the default
            foreach my $change ( @saved_changes ) {
                $change->update({ changeset => $changeset });
            }
        }

        my $dm = $self->schema->data_manager;
        # Now verify based on our columns, make sure everything is still legit
        $dm->verify( $self->verify_scope, { $self->get_columns });

        if ( @errors or not $dm->success ) {
            # Abort out of the transaction
            use Data::Dumper;
            die Dumper({
                errored => \@errors,
                invalid_fields => $dm->bad_fields 
            });
        }
        $self->update;
    };

    try {
        $self->result_source->schema->txn_do( $modify_txn );
    } catch {
        if ( $_ eq 'ERRORS' ) {
            # Intercept this, die with the Data::Manager?
            carp $_;
        } else {
            # Rethrow
            die $_;
        }
    };
}

sub top_queue { shift->queue->top_parent; }

sub is_open { return !shift->is_closed; }

sub is_closed { 
    my ( $self ) = @_;
    my $closed = $self->queue->closed_queue;
    return ( defined $closed && $self->queue_pk1 == $closed->id );
}

# ACL Methods
sub action_list {
    return {
        'comment' => [ 'Owner', 'Member', 'Manager' ],
    }
}

sub is_member {
    my ( $self, $person, $role ) = @_;
    
    return 0 unless defined $person and blessed( $person );

    my $ret = $self->queue->is_member( $person, $role );
  
    # Part of the queue, they're a member here, too. 
    return $ret if $ret; 
    my $search = { };
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

# Verification Code
sub _build_verify_scope { 'ticket' }
sub _build__verify_profile {
    my ( $self ) = @_;
    my $queue_rs     = $self->schema->resultset('Queue');
    my $ident_rs     = $self->schema->resultset('Person::Identity');
    my $priority_rs  = $self->schema->resultset('Ticket::Priority');
    my $type_rs      = $self->schema->resultset('Ticket::Type');
    my $status_rs    = $self->schema->resultset('Status');
    return {
        'profile' => {
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
            'identity_pk1' => {
                'required'   => 1,
                'type'       => 'Holistic::Schema::Person::Identity',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $ident_rs->find( $_ ); }
                )
            },
            'priority_pk1' => {
                'required'   => 1,
                'type'       => 'Holistic::Schema::Ticket::Priority',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $priority_rs->find( $_ ); }
                )
            },
           'type_pk1' => {
                'required'   => 1,
                'type'       => 'Holistic::Schema::Ticket::Type',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $type_rs->find( $_ ); }
                )
            },
           'status_pk1' => {
                'required'   => 0,
                'type'       => 'Holistic::Schema::Status',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $status_rs->find( $_ ); }
                )
            },
           'queue_pk1' => {
                'required'   => 1,
                'type'       => 'Holistic::Schema::Queue',
                'coercion'   => Data::Verifier::coercion(
                    from => 'Int',
                    via  => sub { $queue_rs->find( $_ ); }
                )
            },
        },
        'filters' => [ 'trim' ]
    };
}


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
