package Holistic::Permissions;

use Moose;

has 'scope' => (
    is       => 'ro',
    required => 1,
    does     => 'Holistic::Role::Permissions'
);

has 'schema' => (
    is  => 'ro',
    isa => 'DBIx::Class::Schema',
    lazy_build => 1,
    handles => {
        'resultset' => 'resultset'
    }
);

sub _build_schema { shift->scope->result_source->schema; }

=head1 NAME

Holistic::Permissions

=head1 DESCRIPTION

This module handles permission calculation for any object in the database.

It operates in a hierarchical fashion, which can look up its relationships
(configured by class) to determine a full permission set.

=head1 PERMISSION SETS

Each object has a 'set' that lists what the module can or cannot do.

A Set links to the global Permission table, and each link has an optional
prohibit flag.  This prohibit flag removes the permission, and it will remain
removed unless a more specific permission set re-allows.

Imagine the scenario:

 Product Foo: disallows all write access

 Products has groups:
  * Admin Group
  * Developers

The following would return a subordinate object for managing the set of
permissions specific to the product and group.

 # Returns a permission set scoped by product and group.
 $product->permissions->for( group => $admins ) 

Each set, therefor, has a number of applicable objects and an order.

This is contained in a L<Holistic::Schema::Permission::Set::Object> object,
which points to an object that implements the L<Holistic::Role::Permission> and
a set.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
