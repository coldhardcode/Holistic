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
use Try::Tiny;

my $um = Holistic::Bootstrap->new_with_options;

my $schema = Holistic->model('Schema')->schema;

$schema->txn_do( sub {
    my $role = $schema->resultset('Role')->find_or_create({ name => '@member' });
    my $admin = $schema->resultset('Person')->find_or_create({
        name => $um->username
    });
    try {
        $admin->add_to_identities({
            realm => 'local',
            ident => $um->username,
            secret => $um->password
        });
    }
    catch { warn $_; };

    my $prs = $schema->resultset('Permission');
    my $authenticated = $schema->resultset('Group')->find_or_create({
        name => 'authenticated',
    });
    my $pset = $authenticated->permission_set;
    foreach my $permission ( qw/TICKET_CREATE TICKET_MODIFY/ ) {
        try { $pset->add_to_permissions( $prs->find_or_create({ name => $permission }) ); }
        catch { die $_ unless "$_" =~ /Duplicate/ };
    }
    my $admins = $schema->resultset('Group')->find_or_create({
        name => 'Admin',
    });
    $pset = $admins->permission_set;
    foreach my $permission ( qw/TICKET_CREATE TICKET_MODIFY ADMIN/ ) {
        try { $pset->add_to_permissions( $prs->find_or_create({ name => $permission }) ); }
        catch { die $_ unless $_ =~ /Duplicate/ };
    }

    $admins->add_to_persons( $admin, { role_pk1 => $role->id });
} );

print "You can now login as: " . $um->username . " with the password provided\n";
