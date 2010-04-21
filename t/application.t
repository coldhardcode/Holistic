use Test::More;
use Data::Dumper;

use Holistic::Application;
use Holistic::Ticket;

my $app = Holistic::Application->new(name => 'Holistic', database_host => '10.0.1.13');

my $conn = $app->fetch('Database/connection')->get;
isa_ok($conn, 'MongoDB::Connection');

my $inf = $app->fetch('Inflator')->get;

my $tick = Holistic::Ticket->new(summary => 'A Ticket', description => 'With a description');

my $id = $inf->save($tick);

my $tick2 = $inf->find('Holistic::Ticket', $id);
cmp_ok($tick2->summary, 'eq', 'A Ticket', 'inflated ticket summary');

done_testing;