package Holistic::Verifier;

use Moose;

with 'Holistic::Role::Verifier';

has '+profiles' => (
    default => sub { {
        create_user => {
            email => { type => 'Str', required => 1 }
        }
    } }
);

no Moose;
__PACKAGE__->meta->make_immutable;
