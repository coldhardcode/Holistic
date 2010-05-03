use Test::More;

use Holistic::Stack;
use Holistic::Stack::Step;

use Holistic::Ticket;

# Nothing more than a stack
my $stack = Holistic::Stack->new(
    name => '5.1',
);

ok($stack, "created stack");
$stack->add_child( Holistic::Tree->new( node => 'Backlog' ) );
$stack->add_child( Holistic::Tree->new( node => 'Analysis' ) );

is($stack->size, 3, 'right size');

my $step = Holistic::Tree->new( node => 'Work In Progress' );
    my $dev_step = Holistic::Tree->new( node => 'Development' );
        $dev_step->add_child( Holistic::Tree->new( node => 'Code') );
        $dev_step->add_child( Holistic::Tree->new( node => 'Review') );
    $step->add_child( $dev_step );
    $step->add_child( Holistic::Tree->new( node => 'Test' ) );
    $step->add_child( Holistic::Tree->new( node => 'Merge' ) );

    $stack->add_child( $step );

$stack->add_child( Holistic::Tree->new( node => 'Release' ) );

is($stack->size, 10, 'right size');
is($stack->height, 3, 'right height');
# $stack->clone; # Copy all steps to a new instance.

my $ticket = Holistic::Ticket->new( name => "Fix Everything" );

$stack->add_ticket($ticket);

$stack->traverse(sub {
    my $t = shift;
    print(('    ' x $t->depth) . ($t->node->name || '\undef') . " tickets: " . $t->ticket_count . "\n");
});

diag($ticket->next_step->node);
$ticket->advance;
diag($ticket->step);
is($ticket->step->name, 'Analysis', 'advance!');

diag($ticket->next_step->node->name);
$ticket->advance;
is($ticket->step->name, 'Code', 'advance!');

$ticket->advance;
is($ticket->step->name, 'Review', 'advance!');

$stack->traverse(sub {
    my $t = shift;
    print(('    ' x $t->depth) . ($t->node->name || '\undef') . " tickets: " . $t->ticket_count . "\n");
});

$ticket->advance;
is($ticket->step->name, 'Test', 'advance to parent');

$ticket->advance;
is($ticket->step->name, 'Merge', 'advance to sibling');

$ticket->advance;
is($ticket->step->name, 'Release', 'advance to parent -> sibling');

$stack->traverse(sub {
    my $t = shift;
    print(('    ' x $t->depth) . ($t->node || '\undef') . " tickets: " . $t->ticket_count . "\n");
});

done_testing;
