package Holistic::Schema::Ticket::Person;

use Moose;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__;

$CLASS->table('ticket_persons');

$CLASS->add_columns(
    'pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_auto_increment => 1 },
    'ticket_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    'person_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    'role_pk1',
    { data_type => 'integer', size => 16, is_nullable => 0, is_foreign_key => 1 },
    'active',
    { data_type => 'tinyint', size => 1, is_nullable => 0, default_value => 1 },
    'dt_created',
    { data_type => 'datetime', size => undef, is_nullable => 0,
        set_on_create => 1 },
    'dt_updated',
    { data_type => 'datetime', size => undef, is_nullable => 0,
        set_on_create => 1, set_on_update => 1 },

);

$CLASS->set_primary_key(qw/pk1/);

# XX Add index on ticket and person

$CLASS->belongs_to('ticket', 'Holistic::Schema::Ticket',
    { 'foreign.pk1' => 'self.ticket_pk1' }
);
$CLASS->belongs_to('person', 'Holistic::Schema::Person', 'person_pk1');
$CLASS->belongs_to('role',   'Holistic::Schema::Ticket::Role', 'role_pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
