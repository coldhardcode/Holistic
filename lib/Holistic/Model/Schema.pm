package Holistic::Model::Schema;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'Holistic::Schema',
    #traits => [ '+Holistic::Role::TraitFor::DataManagerFromContext' ]
);

=head1 NAME

Holistic::Model::Schema - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<Holistic>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Holistic::Schema>

=head1 AUTHOR

Jay Shirley

=cut

1;
