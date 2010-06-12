package Holistic::Schema::Label;

use Moose;

use Carp;

extends 'Holistic::Base::DBIx::Class';

with 'Holistic::Role::Verify';

__PACKAGE__->table('labels');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

sub _build_verify_scope { 'label' }
sub _build__verify_profile {
    my ( $self ) = @_;
    my $rs = $self->schema->resultset('Person::Identity');
    return {
        'filters' => [ 'trim' ],
        'profile' => {
            'name' => {
                'required'   => 1,
                'type'       => 'Str',
                'max_length' => '64',
                'min_length' => 1
            },
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
