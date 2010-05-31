#!/usr/bin/env perl

package Trac::UserManager;

use Moose;

with 'MooseX::Getopt';

has [ 'action', 'username', 'password', 'group', 'permissions' ] => (
    is  => 'ro',
    isa => 'Str'
);

package main;


use Holistic;

my $um     = Trac::UserManager->new_with_options;
my $action = lc($um->action);

my $group;
my $person;

# mod_user.pl --action adduser --username foo --password bar --group Developers
my $rs = Holistic->model('Schema::Person');
if ( $action eq 'adduser' ) {
    my $ident = Holistic->model('Schema::Person::Identity')
        ->search(
            { realm => 'local', ident => $um->username },
            { prefetch => [ 'person' ] }
        )->single;
    if ( defined $ident ) {
      die "Username " . $um->username . " already exists, try again!\n"; 
    }
    $person = $rs->create({ name => $um->username });
    $person->add_to_identities({
        realm  => 'local',
        ident  => $um->username,
        secret => $um->password,
    });
}

if ( $um->group ) {
    $group = Holistic->model('Schema::Group')->find({ 'name' => $um->group });
    if ( not defined $group ) {
       die "Group not found, trying to find: " . $um->group . "\n";
    }
    if ( defined $person ) {
        $group->add_to_persons({});
    }
}


my $ident = Holistic->model('Schema::Person::Identity')
    ->search(
        { realm => 'local', ident => $username },
        { prefetch => [ 'person' ] }
    )->single;
die "User not found ($username)!\n"
    unless defined $ident;

my $person = $ident->person;

print "Got person: " . $person->name . "\n";
if ( $password ) {
    $ident->update({ secret => $password });
    print "Updated password\n";
}

print $ident->check_password($password), "\n";
