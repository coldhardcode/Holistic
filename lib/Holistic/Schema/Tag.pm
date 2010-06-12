package Holistic::Schema::Tag;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('tags');

__PACKAGE__->has_many(
    'ticket_links', 'Holistic::Schema::Ticket::Tag',
    { 'foreign.tag_pk1' => 'self.pk1' }
);
__PACKAGE__->many_to_many( 'tickets', 'ticket_links' => 'ticket' );

sub _build_verify_scope { 'tag' }

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
