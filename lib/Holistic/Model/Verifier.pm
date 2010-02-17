package Holistic::Model::Verifier;

use Holistic::Verifier;

use Catalyst::Utils;
use Moose;

extends 'Catalyst::Model::Adaptor';

has 'profiles' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { { } }
);

has 'master' => (
    is   => 'ro',
    does => 'Holistic::Role::Verifier',
    default => sub { Holistic::Verifier->new }
);

__PACKAGE__->config( class => 'Holistic::Verifier' );

sub prepare_arguments {
    my ( $self, $args ) = @_;

    my $p = Catalyst::Utils::merge_hashes( $self->profiles, $self->master->profiles );
    return ( profiles => $p );
    #Holistic::Verifier->new( profiles => $p );
}

no Moose;
__PACKAGE__->meta->make_immutable;
