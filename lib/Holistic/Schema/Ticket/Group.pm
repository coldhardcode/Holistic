package Holistic::Schema::Ticket::Group;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('ticket_groups');

$CLASS->add_columns(
    'foreign_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    'group_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    #'role_pk1',
    #{ data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    'active',
    { data_type => 'tinyint', size => 1, is_nullable => 0, default_value => 1 },
    'dt_created',
    { data_type => 'datetime', size => undef, is_nullable => 0,
        set_on_create => 1 },
);

$CLASS->set_primary_key(qw/foreign_pk1 group_pk1/);

$CLASS->belongs_to('ticket', 'Holistic::Schema::Ticket',
    { 'foreign.pk1' => 'self.foreign_pk1' }
);
$CLASS->belongs_to('group', 'Holistic::Schema::Group', 'group_pk1');

#$CLASS->has_one('role', 'Holistic::Schema::Role',
#    { 'foreign.pk1' => 'self.role_pk1' }
#);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
