use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    with => [ qw/Schema/ ],
    config => {
        connect_info => [
            "dbi:mysql:holistic", 'holistic', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [ 'deploy' ]
);


