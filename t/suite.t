use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ 'Person', 'Queue', 'Ticket', 'Verify', 'Permissions' ],
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
        { 'group_join' => { ident => 'bob', role => 'The Boss' } },
        { 'group_create' => { name => 'Developers' } },
        { 'group_join' => { ident => 'jshirley', role => 'Chief Asshole' } },
        { 'group_join' => { ident => 'gphat', role => 'Pickshur Makur' } },
        'ticket_create',
        'ticket_dependencies',
        'ticket_profile',
        'shut_up_permissions',
    ]
);

