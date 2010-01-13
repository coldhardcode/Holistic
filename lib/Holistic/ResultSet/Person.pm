package Holistic::ResultSet::Person;

use Moose;

extends 'Holistic::Base::ResultSet';

use Catalyst::Utils;
use Carp;

sub register {
    my ( $self, $person, $ident ) = @_;
    my $schema = $self->result_source->schema;

    my $error = {};

    my $person_obj = eval { $self->new_result($person); };
    if ( $@ ) {
        die $@;
    }

    my $known_email = $self->search({ email => $person->{email} })->first;
    croak "Email address $person->{email} is already registered"
        if defined $known_email;

    my $ident_obj = eval { $person_obj->identities->new_result($ident); };
    if ( $@ ) {
        die $@ unless ref $@ eq 'HASH';
        $error = { map { $_ => { value => $person->{$_} } } keys %$person }
            unless keys %$error;
        $error = Catalyst::Utils::merge_hashes($error, $@);
    }
    if ( $error and keys %$error ) {
        die $error;
    }
    $schema->txn_do( sub {
        $person_obj->insert;
        $ident_obj->person_pk1($person_obj->id);
        $ident_obj->insert;
        return ( $person_obj, $ident_obj );
    });
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
