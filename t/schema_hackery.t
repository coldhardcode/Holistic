use Holistic::Test::Suite;
use Test::More;

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
            cmp_ok( $ticket->changes->count, '==', 1, 'change log count' );

            $ticket->modify('advance' => 'Accepted', user => $self->person );
            cmp_ok( $ticket->changes->count, '==', 2, 'change log count' );

            $ticket->modify({ owner => $self->person, user => $self->person });
            cmp_ok( $ticket->changes->count, '==', 3, 'change log count' );

            $ticket->modify({ tag => [ 'tags', 'are', 'good' ] });
            cmp_ok( $ticket->changes->count, '==', 4, 'change log count' );

            $ticket->modify({ priority => 'Urgent', tag => [ 'weee' ] });
            cmp_ok( $ticket->changes->count, '==', 6, 'change log count' );

            if ( 0 ) {
                # Some data_manager
                $self->data_manager;

                $self->schema->txn_do( sub {
                    # this is a different data_manager
                    $self->data_manager;
                } );

                # And now back to the original, pre-transaction data manager?
                $self->data_manager;
                $self->last_data_manager;
            }
        }
    ]
);

