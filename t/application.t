use Test::More;

use Holistic::Application;

my $app = Holistic::Application->new(name => 'Holistic', database_host => '10.0.1.13');

my $conn = $app->fetch('Database/connection')->get;
print "$conn\n";
$conn = $app->fetch('Database/connection')->get;
print "$conn\n";
