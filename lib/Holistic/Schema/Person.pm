package Holistic::Schema::Person;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

with 'Holistic::Role::Actor';

use Data::FormValidator::Constraints;

my $CLASS = __PACKAGE__;

$CLASS->table('persons');
$CLASS->resultset_class('Holistic::ResultSet::Person');

$CLASS->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'token',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0,
        token_field => 'token' },
    'public',
    { data_type => 'tinyint', size => '1', default_value => 1 },
    'email',
    { data_type => 'varchar', size => '255', is_nullable => 1 },
    'postal',
    { data_type => 'vachar', size => '9', is_nullable => 1,
        default_value => '' },
    'country',
    { data_type => 'char', size => '2', is_nullable => 0,
        default_value => 'us' },
    'timezone',
    { data_type => 'varchar', size => '255', is_nullable => 0,
        default_value => 'America/Los_Angeles' },
    dt_created => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1
    },
    dt_updated => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1, set_on_update => 1
    }
);
$CLASS->set_primary_key('pk1');

__PACKAGE__->has_many('identities', 'Holistic::Schema::Person::Identity', 'person_pk1');

__PACKAGE__->many_to_many('comments' => 'identities' => 'comments' );

__PACKAGE__->has_many('group_links', 'Holistic::Schema::Person::Group', 'person_pk1');
__PACKAGE__->many_to_many('groups' => 'group_links' => 'group' );

=head2 connected_to_user($user)

Is this user connected to another user?  This basically just is a check for
exposing visibility.

Facebook ftl.

=cut

sub connected_to_user {
    my ( $self, $user ) = @_;

    return 1 if $self->public;
    return 0 unless $user;
}

sub temporary_password {
    my ( $self ) = @_;

    my $local = $self->identities({ realm => 'local' })->first;
    croak "Unable to create a temporary password without a local password"
        unless $local;

    # Flush out all previous temporary passwords
    $self->identities({ realm => 'temporary' })->delete_all;

    return $self->identities({ realm => 'temporary' })->create({
        id      => $self->email,
        secret  => String::Random::random_string('......\d'),
        realm   => 'temporary'
    });
}

use Digest::MD5;
use URI::Escape qw(uri_escape);

sub gravatar_url {
    my ( $self, $size ) = @_;
    my $email = $self->email;
    my $default = uri_escape('http://static.coldhardcode.com/images/gravatar.jpg');
    $size = int($size || 40);
    $size = 40 if $size < 1;

    return
        'http://www.gravatar.com/avatar.php?' .
        '&gravatar_id=' . Digest::MD5::md5_hex(lc($email)) .
        #"&default=$default" .
        "&size=$size";
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
