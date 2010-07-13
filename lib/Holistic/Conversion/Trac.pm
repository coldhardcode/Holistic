package Holistic::Conversion::Trac;
use Moose;

use Holistic::Schema;

use DBI;
use Text::Trac;
use List::MoreUtils;
use DateTime;
use YAML qw(LoadFile);

with 'MooseX::Getopt';

has config => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has conf => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

has database => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has host => (
    is => 'rw',
    isa => 'Str',
    default => 'localhost'
);

has password => (
    is => 'rw',
    isa => 'Str'
);

has port => (
    is => 'rw',
    isa => 'Int',
    default => 3367
);

has product => (
    is => 'rw',
    isa => 'Str',
    default => 'component'
);

has priority => (
    is => 'rw',
    isa => 'Str',
    default => 'priority'
);

has queue => (
    is => 'rw',
    isa => 'Str',
    default => 'milestone'
);

has tags => (
    is => 'rw',
    isa => 'Bool',
    default => 1
);

has username => (
    is => 'rw',
    isa => 'Str',
    default => 'root'
);

has 'schema' => (
    is  => 'ro',
    isa => 'Holistic::Schema',
    lazy_build => 1,
    handles => {
        'resultset' => 'resultset'
    }
);

has 'trac_parser' => (
    is  => 'ro',
    isa => 'Text::Trac',
    lazy_build => 1,
);

has 'trac_dbh' => (
    is  => 'ro',
    isa => 'DBI::db',
    lazy_build => 1,
    handles => {
        'prepare' => 'prepare'
    }
);

has 'milestone' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_milestone'
);

has 'default_password' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_default_password'
);

has 'trac_groups' => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
);

has 'trac_milestones' => (
    is          => 'ro',
    isa         => 'ArrayRef',
    lazy_build  => 1,
);

has 'types' => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
    traits => [ 'Hash' ],
    handles => {
        'get_type' => 'get'
    }
);

has 'priorities' => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
    traits => [ 'Hash' ],
    handles => {
        'get_priority' => 'get'
    }
);


has 'trac_group_permissions' => (
    is          => 'rw',
    isa         => 'HashRef',
    clearer     => 'clear_trac_group_permissions',
);

has 'trac_user_permissions' => (
    is          => 'rw',
    isa         => 'HashRef',
    clearer     => 'clear_trac_user_permissions',
);

has [ 'person_cache', 'identity_cache', 'milestone_cache', 'developer_groups' ] => (
    is      => 'rw',
    isa     => 'HashRef', 
    default => sub { { } },
    lazy    => 1,
);

sub _build_conf {
    my ( $self ) = @_;
    my $conf = LoadFile($self->config);
# die Dumper($conf->{'Model::Schema'}->{connect_info});
    return $conf;
}

sub _build_schema {
    my ( $self ) = @_;
    my $schema = Holistic::Schema->connect(@{ $self->conf->{'Model::Schema'}->{connect_info} });
}

sub _build_trac_dbh {
    my ( $self ) = @_;
    my $dbh = DBI->connect(
        'DBI:mysql:database='.$self->database.';host='.$self->host.';port='.$self->port,
        $self->username, $self->password
    );
}

sub _build_trac_parser {
    Text::Trac->new( trac_ticket_url => '/ticket/id/' );
}

sub _build_trac_groups {
    my ( $self ) = @_;

    my $sth = $self->prepare('SELECT username, action FROM permission');

    my %row;
    $sth->execute;
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));

    my %users = ();
    while ( $sth->fetch ) {
        $users{ $row{username} } ||= [];
        push @{ $users{ $row{username} } }, $row{action};
    }

    my %groups = (
        'anonymous'     => [],
        'authenticated' => []
    );
    foreach my $key ( keys %users ) {
        foreach my $perm ( @{ $users{$key} } ) {
            # We have a group in this case
            if ( defined $users{$perm} ) {
                $groups{$perm} ||= [];
                push @{ $groups{$perm} }, $key;
            }
        }
    }
    my %group_perms = map { $_ => $users{$_} } keys %groups;
    my %user_perms  =
        # I'm so functional.  Or something.
        map {
            my $user = $_;
            $user => [ grep { not exists $groups{$_} } @{$users{$user}} ]
        }
        grep { not exists $groups{$_} }
        keys %users;

    use Data::Dumper;
    $self->clear_trac_group_permissions;
    $self->clear_trac_user_permissions;
    $self->trac_group_permissions(\%group_perms);
    $self->trac_user_permissions(\%user_perms);
    return \%groups;
}

sub _build_trac_milestones {
    my ( $self ) = @_;

    my $sth = $self->has_milestone ?
        $self->prepare('SELECT * FROM milestone WHERE name = ?') :
        $self->prepare('SELECT * FROM milestone');

    my %row;
    $self->has_milestone ? $sth->execute( $self->milestone ) : $sth->execute;
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));

    my @list;
    while ( $sth->fetch ) {
        push @list, { %row };
    }
    return \@list;
}

sub _build_types {
    my ( $self ) = @_;
    my $sth = $self->prepare('SELECT DISTINCT(type) FROM ticket');

    my %row;
    $sth->execute;
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));

    my $types = {};
    while ( $sth->fetch ) {
        $types->{$row{type}} = $self->resultset('Ticket::Type')->create({
            name => $row{type}
        });
    }
    return $types;
}

sub _build_priorities {
    my ( $self ) = @_;
    my $sth = $self->prepare('SELECT DISTINCT(priority) FROM ticket');

    my %row;
    $sth->execute;
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));

    my $types = {};
    while ( $sth->fetch ) {
        $types->{$row{priority}} = $self->resultset('Ticket::Priority')->create({
            name => $row{priority}
        });
    }
    return $types;
}


sub find_person_and_identity {
    my ($self, $email) = @_;

    $email ||= 'unknown-user@unknown.unknown';

    my $person_rs = $self->resultset('Person');

    # Find a person
    my $person = $self->person_cache->{$email};

    unless(defined($person)) {
        $person = $person_rs->create({
            token   => $email,
            name    => $email,
            public  => 1,
            email   => $email,
            timezone => 'America/Chicago', # XX
        });
        $self->person_cache->{$email} = $person;
    }

    # Find an identity
    my $identity = $person->local_identity;
    unless(defined($identity)) {
        $identity = $person->add_to_identities({
            realm   => 'local',
            ident   => $email,
            secret  => ( $self->has_default_password ? $self->default_password : undef ),
            active  => 1
        });
        $self->identity_cache->{$email} = $identity;
    }

    return ( $person, $identity );
}

sub import_users_and_groups {
    my ( $self ) = @_;

    my $groups   = $self->trac_groups;
    my $role     = $self->resultset('Role')->find_or_create({ name => '@member' });
    my $group_rs = $self->resultset('Group');
    my $perm_rs  = $self->resultset('Permission');

    my %h_groups = ();

    my $group_perms = $self->trac_group_permissions;

    #warn Dumper( $self->trac_groups );
    #warn Dumper( $self->trac_group_permissions );
    #warn Dumper( $self->trac_user_permissions );

    my $owning_groups = {};
    foreach my $group ( keys %$groups ) {
        $h_groups{$group} = $group_rs->find_or_create({ name => $group });
        foreach my $user ( @{ $groups->{$group} } ) {
            my ( $person, $identity ) = $self->find_person_and_identity( $user );
            $h_groups{$group}->add_to_persons( $person, { 'role_pk1' => $role->id });
        }
        my $pset = $h_groups{$group}->permission_set;
        foreach my $permission ( @{ $group_perms->{ $group } } ) {
            $permission =~ s/^TRAC_//;
            if ( $permission eq 'TICKET_MODIFY' ) {
                $owning_groups->{$group} = $h_groups{$group}->id;
            }
            my $p = $perm_rs->find_or_create({ name => $permission });
            $pset->add_to_permissions( $p );
        }
    }

    $self->developer_groups( $owning_groups );
    return [ keys %$groups ];
}

sub import_milestones {
    my ( $self ) = @_;
    my $milestones = $self->trac_milestones;

    my %cache    = ();

    my $rs = $self->resultset('Queue');

    my $open     = $self->resultset('Status')->find_or_create({ name => '@open', accept_tickets => 1, accept_worklog => 1 });
    my $complete = $self->resultset('Status')->find_or_create({ name => '@completed', accept_tickets => 0, accept_worklog => 0 });

    foreach my $ms ( @$milestones ) {
        my $token = $self->schema->tokenize($ms->{name});
        my $queue = $rs->create({
            name        => $ms->{name},
            token       => $token,
            path        => $token,
            description => $ms->{description},
            status_pk1  => ( $ms->{completed} ? $complete->id : $open->id ),
            traversal_type => 2
        });
        my $developer_groups = $self->developer_groups;
        foreach my $key ( keys %$developer_groups ) {
            $queue->group_links->create({ group_pk1 => $developer_groups->{$key} });
        }
        # XX this needs to be fixed, we can figure out based on the
        # ticket_changes how it progresses.
        foreach my $step ( qw/new assigned testing closed/ ) {
            $cache{"$ms->{name}.$step"} = $queue->add_step({
                name  => ( '@' . $step ),
                token => $step
            });
        }
        $cache{"$ms->{name}"} = $queue;
        $queue->update({ closed_queue_pk1 => $cache{"$ms->{name}.closed"}->id });
        $queue->all_children->update({ closed_queue_pk1 => $cache{"$ms->{name}.closed"}->id });
    }
    $self->milestone_cache(\%cache);
}

sub import_tickets {
    my ( $self ) = @_;

    my $sth;
    if ( $self->has_milestone ) {
        $sth = $self->prepare('SELECT * FROM ticket WHERE milestone = ?');
        $sth->execute( $self->milestone );
    } else {
        $sth = $self->prepare('SELECT * FROM ticket');
        $sth->execute;
    }

    my $worklog_type = $self->resultset('Comment::Type')->find_or_create({ name => '@worklog' });
    my $rs = $self->resultset('Ticket');
    my %row;
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));

    my $change_sth = $self->prepare("SELECT author, field, time, newvalue FROM ticket_change WHERE ticket=? ORDER BY TIME ASC");

    my @list;
    while ( $sth->fetch ) {
        my $milestone = $self->milestone_cache->{$row{milestone}};
        my $state     = $row{status};
           $state     = 'new' if $state eq 'reopened';
        $row{milestone} ||= 'X';
        my $status    = $self->milestone_cache->{join('.', $row{milestone}, $row{status})};
        my ($rep_person, $rep_ident) = $self->find_person_and_identity($row{reporter});
        my ($own_person, $own_ident) = $self->find_person_and_identity($row{owner});

        my $desc = $self->trac_parser->parse($row{description});
        my $tick = $rs->create({
            pk1             => $row{id},
            identity_pk1    => $rep_ident->id,
            type_pk1        => $self->get_type($row{type})->id,
            priority_pk1    => $self->get_priority($row{$self->priority})->id,
            name            => $row{summary},
            description     => $desc,
            queue_pk1       => $status->id,
            dt_created      => DateTime->from_epoch(epoch => $row{time}),
            dt_updated      => DateTime->from_epoch(epoch => $row{changetime})
        });


        $tick->requestor($rep_person);
        $tick->owner($own_person);

        $change_sth->execute($row{id});
        my %change_row;
        $change_sth->bind_columns( \( @change_row{ @{$change_sth->{NAME_lc} } } ));
        while ($change_sth->fetch) {
            # Use the system user if there's no author
            # XX this only works if you use emails, should probably use token or whatever
            $change_row{author} = 'no-reply@coldhardcode.com' unless(defined($change_row{author}) && $change_row{author} ne '');
            my ($change_person, $change_ident) = $self->find_person_and_identity($change_row{author});
            $tick->add_to_changes({
                identity_pk1 => $change_ident->id,
                name         => $change_row{field},
                value        => $change_row{newvalue} || '',
                changeset    => $change_row{time},
                dt_created   => DateTime->from_epoch(epoch => $change_row{time}),
            }) unless $change_row{field} eq 'comment'; # Comments aren't changes

            # Comments
            if($change_row{field} eq 'comment') {
                # No reason to have empty ones
                next unless defined($change_row{newvalue}) && $change_row{newvalue} ne '';

                my $html = $self->trac_parser->parse($change_row{newvalue});
                next if !defined($html) || ($html eq '');
                my $is_worklog = 0;
                if ( $html =~ /changeset/ ) {
                    $is_worklog = 1;
                }
                $tick->add_comment({
                    identity => $change_ident,
                    body => $html,
                    dt_created => DateTime->from_epoch(epoch => $change_row{time}),
                    ( $is_worklog ? ( type_pk1 => $worklog_type->id ) : () )
                });
            # State (resolution in Trac) changes
            } elsif($change_row{field} eq 'resolution') {
                # Here we find the appropriate closed state
                $tick->update({ queue_pk1 => $milestone->closed_queue->id });
            }
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
