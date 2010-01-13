package Holistic::Schema::Person::Identity;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('person_identities');

$CLASS->add_columns(
    'person_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0 },
    'realm',
    { data_type => 'varchar', size => 64, is_nullable => 0 },
    'id',
    { data_type => 'varchar', size => 64, is_nullable => 0 },
    'secret',
    {
        data_type       => 'VARCHAR',
        size            => 64,
        is_nullable     => 1,
        encode_column   => 1,
        encode_class    => 'Digest',
        encode_args     => { algorithm => 'SHA-1', format => 'hex' },
        encode_check_method => 'check_password',
    },
    'active',
    { data_type => 'tinyint', size => 1, is_nullable => 0, default_value => 1 },
    'dt_created',
    { data_type => 'datetime', size => undef, is_nullable => 0,
        set_on_create => 1 },
);

$CLASS->set_primary_key(qw/person_pk1 realm id/);

$CLASS->belongs_to('person', 'Holistic::Schema::Person', 'person_pk1');

$CLASS->add_unique_constraint(
    realm_id_constraint => [ qw/realm id/ ]
);

# TODO: Decide on indexes
sub sqlt_deploy_hook {
    my ( $self, $sqlt_table ) = @_;
    $sqlt_table->add_index( name => 'person_pk1_idx', fields => [ 'person_pk1' ]);
}

1;
