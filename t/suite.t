use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ 'Person' ],
    config => {
        connect_info => [
            'dbi:SQLite:t/var/test.db',
            '', '',
            { quote_char => '`', name_sep => '.' }
        ]
    }
);

