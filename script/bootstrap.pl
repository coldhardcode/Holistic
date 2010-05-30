#!/usr/bin/env perl

package Holistic::Bootstrap;

use Moose;

with 'MooseX::Getopt';

has [ 'username', 'password' ] => (
    is  => 'ro',
    isa => 'Str',
    required => 1
);

package main;


use Holistic;

my $um = Holistic::Bootstrap->new_with_options;

my $schema = Holistic->model('Schema')->schema;

$schema->txn_do( sub {
    my $role = $schema->resultset('Role')->find_or_create({ name => '@member' });
    my $admin = $schema->resultset('Person')->create({
        name => $um->username
    });
    $admin->add_to_identities({
        realm => 'local',
        ident => $um->username,
        secret => $um->password
    });

    my $prs = $schema->resultset('Permission');
    my $authenticated = $schema->resultset('Group')->find_or_create({
        name => 'authenticated',
    });
    my $pset = $authenticated->permission_set;
    foreach my $permission ( qw/TICKET_CREATE TICKET_MODIFY/ ) {
        $pset->add_to_permissions( $prs->find_or_create({ name => $permission }) );
    }
    my $admins = $schema->resultset('Group')->find_or_create({
        name => 'Admin',
    });
    $pset = $admins->permission_set;
    foreach my $permission ( qw/TICKET_CREATE TICKET_MODIFY ADMIN/ ) {
        $pset->add_to_permissions( $prs->find_or_create({ name => $permission }) );
    }

    $admins->add_to_persons( $admin, { role_pk1 => $role->id });
} );

print "You can now login as: " . $um->username . " with the password provided\n";
