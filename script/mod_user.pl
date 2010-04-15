#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use Holistic;

my ( $username, $password ) = @ARGV;

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
