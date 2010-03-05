use Holistic::Test::Suite;

use DateTime;

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
        { ticket_create => {
            priority => 'Normal',
            name => 'Awesome Test Ticket',
            dt_created => DateTime->now->add(days => 1)
        } },
        'do_search',
        { 'do_search' => { query => 'name:Awesome', count => 1 } },
        { 'do_search' => { query => 'name="Awesome Test Ticket"', count => 1 } },
        { 'do_search' => { query => 'name="Test Ticket"', count => 0 } },
        { 'do_search' => { query => 'priority=Normal', count => 1 } },
        { 'do_search' => { query => 'priority=Urgent', count => 0 } },
        { 'do_search' => { query => 'date_created>"'.DateTime->now->strftime('%F %T').'"', count => 1 } },
        { 'do_search' => { query => 'date_created<"'.DateTime->now->strftime('%F %T').'"', count => 0 } },
    ]
);

