package Holistic::Model::DataManager;

use Moose;
use Try::Tiny;

use Holistic::DataManager;

extends 'Catalyst::Model';

with 'Catalyst::Component::InstancePerContext';

has 'verifiers' => (
    is  => 'rw',
    isa => 'HashRef',
    traits => [ 'Hash' ],
    lazy_build => 1,
);

has 'scope_to_resultsource' => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { { } },
);

sub build_per_context_instance {
    my ( $self, $c ) = @_;

    Holistic::DataManager->new(
        verifiers             => $self->verifiers,
        scope_to_resultsource => $self->scope_to_resultsource
    );
}

sub _build_verifiers {
    my ( $self ) = @_;
    # XX This is hacky:
    my $schema  = Holistic->model('Schema')->schema;
    my $ret     = {};

    foreach my $name ( $schema->sources ) {
        my $source = $schema->class($name)->new;

        next unless $source->can('meta');
        next unless $source->meta->does_role('Holistic::Role::Verify');
        $ret->{$source->verify_scope} = $source->verifier;
        $self->scope_to_resultsource->{ $source->verify_scope } = "Schema::$name
";
    }
    $ret;
};

no Moose;
__PACKAGE__->meta->make_immutable;

