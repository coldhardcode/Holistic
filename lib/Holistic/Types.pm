package Holistic::Types;

use MooseX::Types -declare => [qw(TicketPriority TicketType HolisticNode)];
use MooseX::Types::Moose qw/Str HashRef Object/;

use Holistic::Node;

enum TicketPriority,
    (qw/Highest High Normal Low Lowest/);

enum TicketType,
    (qw/Enchancement Defect Task/);

# type definition.

class_type HolisticNode, { class => 'Holistic::Node' };
coerce HolisticNode,
    from Str,
    via { Holistic::Node->new( name => $_ ) };

1;

