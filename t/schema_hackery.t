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
            is($ticket->queue->path, 'trac.wip.assigned');

            $ticket->modify('advance' => 'Wontfix', user => $self->person );
            cmp_ok( $ticket->changes->count, '==', 2, 'change log count' );
            is($ticket->queue->path, 'trac.closed.wontfix');

            $ticket->modify({ owner => $self->person, user => $self->person });
            cmp_ok( $ticket->changes->count, '==', 3, 'change log count' );
            
            $ticket->modify({ attention => $self->person, user => $self->person });
            cmp_ok( $ticket->changes->count, '==', 4, '- change log count' );
            diag($ticket->needs_attention->first);
            cmp_ok(
                $ticket->needs_attention->first->id , '==',
                $self->person->id, 
                'attention ok'
            );

            $ticket->modify({ tag => [ 'tags', 'are', 'good' ] });
            cmp_ok( $ticket->changes->count, '==', 5, 'change log count' );

            $ticket->modify({ priority => 'Urgent', tag => [ 'weee' ] });
            cmp_ok( $ticket->changes->count, '==', 7, 'change log count' );

            my $now = DateTime->now;
            $ticket->modify({ due_date => $now, user => $self->person });
            cmp_ok( $ticket->changes->count, '==', 8, 'change log count' );
            is_deeply( [ $ticket->due_date->dt_marker ], [ $now ], 'right due date' );
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

