use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ qw/
        Person Queue Ticket Verify Permissions Search
    /],
    config => {
        connect_info => [
            "dbi:mysql:holistic", 'holistic', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [
        'deploy',
        { 'person_create' => { name => 'J. Shirley', ident => 'jshirley', email => 'jshirley@coldhardcode.com', secret => 'test' } },
        { 'person_create' => { name => 'Cory Watson', ident => 'gphat', email => 'gphat@coldhardcode.com', secret => 'test' } },
        { 'person_create' => { name => 'Bob', ident => 'bob', email => 'bob@coldhardcode.com', secret => 'test' } },
        { 'group_create' => { name => 'Managers' } },
        { 'group_join' => { ident => 'bob', role => 'The Boss' } },
        { 'group_create' => { name => 'Developers' } },
        { 'group_join' => { ident => 'jshirley', role => 'Chief Asshole' } },
        { 'group_join' => { ident => 'gphat', role => 'Pickshur Makur' } },
        'ticket_create',
        'ticket_dependencies',
        'ticket_profile',
        'do_search',
        'shut_up_permissions',
    ]
);

