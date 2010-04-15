package Holistic::Schema::Person::Identity;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->load_components(qw/EncodedColumn/);

$CLASS->table('person_identities');

$CLASS->add_columns(
    'pk1',
    {
        data_type   => 'integer',
        is_nullable => 0,
        size        => 16,
        is_auto_increment => 1,
    },
    'person_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0 },
    'realm',
    { data_type => 'varchar', size => 64, is_nullable => 0 },
    'ident',
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

$CLASS->set_primary_key(qw/pk1/);

$CLASS->belongs_to('person', 'Holistic::Schema::Person', 'person_pk1');

$CLASS->has_many(
    'comments', 'Holistic::Schema::Comment', 
    { 'foreign.identity_pk1' => 'self.pk1' }
);

$CLASS->add_unique_constraint(
    realm_ident_constraint => [ qw/realm ident/ ]
);

$CLASS->add_unique_constraint(
    person_realm_id_constraint => [ qw/person_pk1 realm ident/ ]
);

$CLASS->has_many(
    'ticket_states', 'Holistic::Schema::Ticket::FinalState',
    { 'foreign.identity_pk1' => 'self.pk1' }
);
$CLASS->many_to_many('tickets' => 'ticket_states' => 'ticket');

# TODO: Decide on indexes
sub sqlt_deploy_hook {
    my ( $self, $sqlt_table ) = @_;
    $sqlt_table->add_index( name => 'person_pk1_idx', fields => [ 'person_pk1' ]);
}

sub needs_attention {
    my ( $self ) = @_;

    my $status = $self->result_source->schema->get_status('@ATTENTION');

    $self->schema->resultset('Ticket')->search(
        { 
            'final_state.status_pk1'   => $status->id,
            'final_state.identity_pk2' => $self->id
        },
        {
            prefetch => [ 'final_state' ],
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
