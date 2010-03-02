use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ 'Person', 'Queue', 'Ticket', 'Search' ],
    config => {
        connect_info => [
            'dbi:SQLite:t/var/test.db',
            '', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [
        'deploy',
        'ticket_create',
        'ticket_dependencies',
        'ticket_profile',
        'do_search',
    ]
);

