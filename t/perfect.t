my $joe   = Holistic::Person->new( name => 'Joe', email => 'joe@joes.com' );
my $bill  = Holistic::Person->new( name => 'Bill', email => 'bill@joes.com' );
my $frank = Holistic::Person->new( name => 'Frank', email => 'frank@joes.com' );

my $techs = Holistic::Group->new( name => 'Technical Team' );
    $techs->add_member( $joe, roles => [ 'Manager' ] );
    $techs->add_member( $bill, roles => [ 'Helper' ] );
    $techs->add_member( $frank, roles => [ 'Developer' ] );

my $goal = Holistic::Goal->new(
    name        => '2010Q1 Maintenance',
    due_date    => '2010-03-31',
    start_date  => '2010-01-01',
    group       => $techs,
);

my $ticket = Holistic::Ticket->new(
    subject => "Place drop it",
    body    => "Become I don't want it",
    requestor => 'anon@dumbasses.com'
);

my $pipe = Holistic::Pipe->new( name => 'Customer Service' );
# $pipe->add_to_rules(...);
    # Automatically add CC recipients
    $pipe->add_to_rules({ action => 'CC', address => [ 'bob@manager.com' ] });
    # Move the ticket
    $pipe->add_to_rules({ action => 'Notify', group => [ $techs ] });

my $receipt = $pipe->accept($ticket);

# Joe can then assign work units
my $subticket = $ticket->add_work_unit({
        subject => 'Unsubscribe',
        body    => 'Bill, unsubscribe this person',
        requestor => $joe  
    });

# Unassigned work unit (ticket type) that is too big, migrate to a full ticket.
my $subticket2 = $ticket->add_work_unit({
    subject => 'Self-Service Unsubscribe',
    body    => 'need unsubscribe mechanism to stop getting these tickets',
    requestor => $joe
});

my $ticket2 = Holistic::Ticket->new(
    subject     => "Let Users Unsubscribe",
    body        => "Ticket for handling self-service",
    requestor   => $frank,
    goal        => $q1,
);

# Migrate the work unit
$ticket2->migrate( $subticket2, traits => [ 'Work Escalation' ] );
