package Holistic::Schema::Role;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Schema::Label';

__PACKAGE__->table('roles');

__PACKAGE__->has_many(
    'person_links', 'Holistic::Schema::Person::Group',
    { 'foreign.role_pk1' => 'self.pk1' }
);

__PACKAGE__->many_to_many( 'groups', 'person_links' => 'group' );

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
