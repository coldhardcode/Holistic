package Holistic::Schema::TimeMarker;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

with 'Holistic::Role::Verify';

__PACKAGE__->table('timemarkers');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'foreign_pk1',
    { data_type => 'integer', size => '16' },
    'rel_source',
    { data_type => 'varchar', size => '255' },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'dt_marker',
    { data_type => 'datetime', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->add_relationship(
    'queue', 'Holistic::Schema::Queue',
    {
        'foreign.pk1'        => 'self.foreign_pk1',
        'foreign.rel_source' => 'self.rel_source'
    },
    { accessor => 'single', join_type => 'LEFT', is_foreign_key_constraint => 0 },
);

__PACKAGE__->add_relationship(
    'ticket', 'Holistic::Schema::Ticket',
    {
        'foreign.pk1'        => 'self.foreign_pk1',
        'foreign.rel_source' => 'self.rel_source'
    },
    { accessor => 'single', join_type => 'LEFT', is_foreign_key_constraint => 0 },
);

sub _build_verify_scope { 'timemarker' }
sub _build__verify_profile {
    my ( $self ) = @_;

    use DateTimeX::Easy;
    return {
        'profile' => {
            # XX This should be a valid, parsed time
            'dt_marker' => {
                'required' => 1,
                'type'     => 'DateTime',
                coercion   => Data::Verifier::coercion(
                    from => 'Str',
                    via  => sub { DateTimeX::Easy->parse( $_ ); }
                )
            },
            'name' => {
                'required'   => 1,
                'type'       => 'Str',
                'min_length' => 1
            },
        },
        'filters' => [ 'trim' ]
    };
}

# ±X This really breaks down.
sub changelog_string {
    my ( $self ) = @_;
    return $self->dt_marker;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
