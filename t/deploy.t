use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    with => [ qw/Schema/ ],
    config => {
        connect_info => [
            "dbi:mysql:holistic", 'root', '',
            { quote_char => '`', name_sep => '.', 'mysql_enable_utf8' => 1 }
        ]
    },
    tests => [ 'deploy' ]
);


