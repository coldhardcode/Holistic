package Holistic::Schema::Ticket::Change;

use Moose;

use Digest::SHA1 qw(sha1_hex);

extends 'Holistic::Schema::Ticket::Meta';

__PACKAGE__->load_components(qw(Ordered Core));
__PACKAGE__->table('ticket_changes');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_auto_increment => 1 },
    'ticket_pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_foreign_key => 1 },
    'identity_pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_foreign_key => 1 },
    'changeset',
    { data_type => 'varchar', size => '40', is_nullable => 0,
        dynamic_default_on_create => sub {
            my $self = shift;
            sha1_hex(join("\n", $self->ticket_pk1, $self->name, $self->value));
        } 
    },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'value',
    { data_type => 'text', is_nullable => 0 },
    'position',
    { data_type => 'integer', is_nullable => 0 },
    'dt_created',
    { data_type => 'datetime', is_nullable => 0, set_on_create => 1 },
);

__PACKAGE__->set_primary_key(qw/pk1/);
__PACKAGE__->add_unique_constraint(
    'ticket_changes_changeset_idx' => [ qw/ticket_pk1 changeset name/ ]
);
__PACKAGE__->position_column('position');
__PACKAGE__->grouping_column('changeset');

__PACKAGE__->belongs_to( 'ticket', 'Holistic::Schema::Ticket', 'ticket_pk1' );
__PACKAGE__->belongs_to( 'identity', 'Holistic::Schema::Person::Identity', 'identity_pk1' );

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

