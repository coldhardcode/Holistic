package Holistic::Schema::Comment::Type;

use Moose;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('comment_types');

__PACKAGE__->has_many('comments', 'Holistic::Schema::Comment', 'type_pk1');

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
