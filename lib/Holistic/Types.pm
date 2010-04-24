package Holistic::Types;
use MooseX::Types -declare => [qw(TicketPriority TicketType)];

enum TicketPriority,
    (qw/Highest High Normal Low Lowest/);

enum TicketType,
    (qw/Enchancement Defect Task/);