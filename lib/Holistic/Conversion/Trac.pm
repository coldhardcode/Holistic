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

has [ 'person_cache', 'identity_cache' ] => (
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

    foreach my $group ( keys %$groups ) {
        $h_groups{$group} = $group_rs->find_or_create({ name => $group });
        foreach my $user ( @{ $groups->{$group} } ) {
            my ( $person, $identity ) = $self->find_person_and_identity( $user );
            $h_groups{$group}->add_to_persons( $person, { 'role_pk1' => $role->id });
        }
        my $pset = $h_groups{$group}->permission_set;
        foreach my $permission ( @{ $group_perms->{ $group } } ) {
            $permission =~ s/^TRAC_//;
            my $p = $perm_rs->find_or_create({ name => $permission });
            $pset->add_to_permissions( $p );
        }
    }

    return [ keys %$groups ];
}

no Moose;
__PACKAGE__->meta->make_immutable;
