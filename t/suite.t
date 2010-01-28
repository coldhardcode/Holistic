use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ 'Person', 'Ticket' ],
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
        { 'group_create' => { name => 'Developers' } },
        { 'group_join' => { ident => 'jshirley', role => 'Chief Asshole' } },
        { 'group_join' => { ident => 'gphat', role => 'Pickshur Makur' } },
        'ticket_create',
        'ticket_dependencies',
    ]
);

