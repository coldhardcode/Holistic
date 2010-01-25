package Holistic::Schema::Ticket::Tag;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('ticket_tags');

__PACKAGE__->add_columns(
    'ticket_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
    'tag_pk1',
    { data_type => 'integer', size => '16', is_foreign_key => 1 },
);

__PACKAGE__->set_primary_key(qw/ticket_pk1 tag_pk1/);

__PACKAGE__->belongs_to('ticket', 'Holistic::Schema::Ticket', 'ticket_pk1');
__PACKAGE__->belongs_to('tag', 'Holistic::Schema::Tag', 'tag_pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

