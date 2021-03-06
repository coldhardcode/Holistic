#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use Holistic;

my ( $name, $username, $password ) = @ARGV;

die "add_user.pl name username password\n" unless defined($name) && defined($username) && defined($password);

my $person = Holistic->model('Schema::Person')
    ->create({ name => $name, token => $username });
$person->add_to_identities({ realm => 'local', ident => $username, secret => $password });

print "User added, ID #" . $person->id . "\n";

