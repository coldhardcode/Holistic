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

# Something like a status bot would be cool.  I envision dialog like this:
# <frank> bot: working ticket #123
# <bot> ok
# <joetheboss> what's frank working on?
# <bot> as of 1 hour, 27 minutes ago, on ticket #123 <link>
# <joetheboss> who is working on #122?
# <bot> nobody is working on #122, but bill was 3 hours ago. #122 is 
#      currently assigned to bill.
# <frank> &
# <bot> ok, frank.  pausing work on #123
#
# If someone signs off, and a persistent mode is checked, work is automatically
# paused.  We can have the states list similar to the Brittle effects.
$subticket2->add_to_states({
    traits      => [ 'WIP' ],
    actor       => $frank,
    start_time  => $now
});

$subticket2->add_to_states({
    traits      => [ 'Rest' ],
    actor       => $frank,
    start_time  => $now
});

# We can have auto-triggers, so when a state with the trait of Testing it
# can automatically reassign
$subticket2->add_to_states({
    # In this case, Frank it testing it out.
    traits      => [ 'WIP', 'Testing' ],
    actor       => $frank,
    start_time  => $now
});

# From a UI perspective, each actor role (tester, worker, developer, etc) should
# have a flexible UI built up by them or the managers.  Complete with state
# hot buttons, to automatically add the most common states to the tickets.
#
# Of course, the coolest thing would be to just use the bot.
$goal->make_pretty_reports;
