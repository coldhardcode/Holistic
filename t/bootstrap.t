use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    with => [ qw/Schema Person Permissions/ ],
    config => {
        connect_info => [
            "dbi:mysql:holistic", 'root', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [
        'deploy',
        'bootstrap',
        { 'person_create' => { name => 'Cory Watson', ident => 'gphat', email => 'gphat@coldhardcode.com', password => 'test' } },
        { 'group_create' => { name => 'Developers', permissions => [ qw/TICKET_ADMIN TICKET_VIEW/ ] } },
        { 'group_join' => { ident => 'gphat' } },
    ]
);


