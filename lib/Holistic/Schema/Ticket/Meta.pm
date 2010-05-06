package Holistic::Schema::Ticket::Meta;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('ticket_metas');

__PACKAGE__->add_columns(
    'ticket_pk1',
    { data_type => 'integer', size => '16', is_nullable => 0, is_foreign_key => 1 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'value',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'position',
    { data_type => 'integer', is_nullable => 0 }
);

__PACKAGE__->set_primary_key(qw/ticket_pk1 name/);

__PACKAGE__->belongs_to( 'ticket', 'Holistic::Schema::Ticket', 'ticket_pk1' );

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
