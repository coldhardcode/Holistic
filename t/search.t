use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ qw/
        Person Queue Ticket Verify Permissions Search
    / ],
    config => {
        connect_info => [
            'dbi:SQLite:t/var/test.db',
            '', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [
        'deploy',
        { 'person_create' => { name => 'J. Shirley', ident => 'jshirley', email => 'jshirley@coldhardcode.com' } },
        { 'person_create' => { name => 'Cory Watson', ident => 'gphat', email => 'gphat@coldhardcode.com' } },
        { 'person_create' => { name => 'Bob', ident => 'bob', email => 'bob@coldhardcode.com' } },
        { 'group_create' => { name => 'Managers' } },
        'ticket_create',
        'ticket_dependencies',
        'ticket_profile',
        'do_search',
    ]
);

