use Holistic::Test::Suite;

my $suite = Holistic::Test::Suite->new;

$suite->run(
    #with => [ 'Person', 'Group', 'Ticket' ],
    with => [ qw/ Person Queue Ticket /],
    config => {
        connect_info => [
            "dbi:mysql:holistic", 'holistic', '',
            { quote_char => '`', name_sep => '.' }
        ]
    },
    tests => [
        'deploy',
        { 'person_create' => { name => 'J. Shirley', ident => 'jshirley', email => 'jshirley@coldhardcode.com', password => 'test' } },
        { 'group_create' => { name => 'Managers' } },
        { 'group_create' => { name => 'Developers', permissions => [ qw/TICKET_ADMIN TICKET_VIEW/ ] } },
        { 'group_join' => { ident => 'jshirley', role => 'Chief Asshole' } },
        'ticket_create',
        sub {
            my ( $self ) = @_;

            my $ticket = $self->ticket;
            $ticket->modify({ 'advance' => 1, user => $self->person });

            $ticket->modify('advance' => 'Accepted', user => $self->person );

            $ticket->modify({ owner => $self->person, user => $self->person });

            $ticket->modify({ tag => [ 'tags', 'are', 'good' ] });

            $ticket->modify({ priority => 'Urgent' });

            $ticket->modify({ priority => 'Urgent' });
        }
    ]
);

