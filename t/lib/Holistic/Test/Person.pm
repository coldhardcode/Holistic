package Holistic::Test::Person;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;
use Try::Tiny;

with 'Holistic::Test::Schema'; # We require schema

has 'person' => (
    is => 'rw',
);

has 'group' => (
    is => 'rw',
);

sub person_create : Plan(1) {
    my ( $self, $data ) = @_;

    my $person = $self->schema->resultset('Person')->create({
        name  => $data->{name}  || 'J. Shirley',
        token => $data->{ident} || 'jshirley',
        email => $data->{email} || 'jshirley@coldhardcode.com',
    });

    ok( $person, 'created person' );
    $self->person( $person );

    my $local = $person->add_to_identities({
        realm  => 'local',
        ident  => $person->token,
        secret => ( $data->{password} || 'test-script-generated' )
    });

    ok( $local->check_password( $data->{password} || 'test-script-generated' ),
        'password check'
    );
    $person->add_to_identities( { realm => 'twitter', ident => $person->token } );
    $person->add_to_identities( { realm => 'irc', ident => $person->token } );

    $person->add_to_identities(
        { realm => 'git', ident => $person->token . '@foo', secret => 'public key?' }
    );
}

sub group_create : Plan(1) {
    my ( $self, $data ) = @_;
    $data ||= {};

    my $group = $self->resultset('Group')->create({
        name  => $data->{name}  || 'Test Group',
        token => $data->{token} || 'test_group',
        email => $data->{email} || 'group@holistic.us',
    });
    ok( $group, 'created group' );
    $self->group( $group );

    if ( $data->{permissions} ) {
        my @perms = ref $data->{permissions} ?
            @{ $data->{permissions} } : ( $data->{permissions} );
        my $pset = $group->permission_set;
        foreach my $perm ( @perms ) {
            my $p = $self->resultset('Permission')->find_or_create({ name => $perm });
            $pset->add_to_permissions( $p );
        }
        # XX this is a total bullshit test.
        is_deeply(
            [ sort keys %{ $group->inflate_permissions } ],
            [ sort @perms ],
            'inflation test'
        );
    }
    $group;
}

sub group_join : Plan(5) {
    my ( $self, $data ) = @_;
    $data ||= {};

    my $group;
    my $person;

    if ( $data->{group} ) {
        $group = $self->resultset('Group')->search({ name => $data->{group} })->first;
        confess "Specified group can't be found, $data->{group} doesn't exist!"
            unless defined $group;
    } else {
        $group = $self->group;
    }

    if ( $data->{ident} ) {
        $person = $self->resultset('Person::Identity')->search({ ident => $data->{ident}, realm => 'local' })->first;
        confess "Specified identity can't be found, $data->{ident} doesn't exist with local realm!" unless defined $person;
        $person = $person->person;
    } else {
        $person = $self->person;
    }

    if ( not defined $group ) {
        $self->run_test('group_create');
        $group = $self->group;
    }
    if ( not defined $person ) {
        $self->run_test('person_create');
        $person = $self->person;
    }
    my $count = $group->persons->count;

    my $role = $self->schema->get_role( $data->{role} || 'Test Role' );

    $group->add_to_persons($person, { role_pk1 => $role->id } );

    cmp_ok($group->persons->count, '==', $count + 1, 'right member count');
    ok(
        $group->persons({ 'person_pk1' => $person->id, 'role_pk1' => $role->id })->count, 'finding person with role'
    );
    ok( $group->is_member( $person ), 'person is a member' );
    
    my $err;
    try {
        $group->is_member( $person, 'Made Up Role' );
    } catch {
        $err = $_;
    };

    ok( $err =~ /unknown to the system/, 'exception from invalid role' );
    ok( $group->is_member( $person, $role ), 'person is a member with right role' );
}

1;
