use Test::More;
use Data::Dumper;

use Holistic::Application;
use Holistic::Ticket;
use Holistic::Person;

my $app = Holistic::Application->new(name => 'Holistic', database_host => '10.0.1.13');
ok($app, 'created application');
my $conn = $app->fetch('Database/connection')->get;
isa_ok($conn, 'MongoDB::Database');

# my $inf = $app->fetch('Inflator')->get;

my $tick = Holistic::Ticket->new(summary => 'A Ticket', description => 'With a description');

my $person = Holistic::Person->new( name => 'Bob Hope' );

$tick->add_requestor( $person );

# my $id = $inf->save($tick);

# my $tick2 = $inf->find('Holistic::Ticket', $id);
# cmp_ok($tick2->summary, 'eq', 'A Ticket', 'inflated ticket summary');

my $tickets = $app->fetch('Kioku/tickets')->get;

my $s = $tickets->new_scope;
my $uuid = $tickets->store($tick);
diag($uuid);

my $foo = $tickets->search({ summary => 'A Ticket' });
while(my $block = $foo->next) {
    foreach my $obj (@$block) {
        diag($obj->summary);
    }
}

# my $searcher = $app->fetch('Searcher/tickets')->get;
# 
# $searcher->search({ summary => 'A Ticket' });
# $searcher->search({ description => 'With a description' });
# 
# my $cursor = $searcher->get_results;
# 
# my $tickets = $searcher->inflate_results($cursor);
# ok(scalar(@{ $tickets}), 'got some tickets');

done_testing;
