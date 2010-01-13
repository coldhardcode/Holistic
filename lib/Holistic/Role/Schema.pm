package Holistic::Role::Schema;

use Moose::Role;

use Carp;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    lazy_build => 1
);

has 'schema_class' => (
    is          => 'ro',
    isa         => 'Str',
    default     => 'Holistic::Schema'
);

has 'connect_info' => (
    is          => 'rw',
    isa         => 'ArrayRef',
    required    => 1
);

sub _build_schema {
    my ( $self ) = @_;

    my $class = $self->schema_class;
    Class::MOP::load_class( $class );
    my $schema = $class->connect( @{ $self->connect_info } );
    return $schema;
}

no Moose::Role;

1;
