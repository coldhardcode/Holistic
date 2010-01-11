package Holistic::Roles::Schema;

use Moose::Role;
use Holistic::Schema;
use Carp;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    lazy_build => 1
);

has 'connect_info' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [ ] }
);

sub _build_schema {
    my ( $self ) = @_;
    my $schema = Holistic::Schema->connect( @{ $self->connect_info } );
    return $schema;
}

1;
