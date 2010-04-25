package Holistic::Ticket::Assignments;

use Moose;

has 'owners' => (
    is     => 'rw',
    isa    => 'ArrayRef[Holistic::Person]',
    traits => [ 'Array' ],
    lazy => 1,
    default => sub { [ ] },
    handles => {
        'all_owners' => 'elements',
        'add_owner'  => 'push',
    }
);

has 'requestor' => (
    is     => 'rw',
    isa    => 'ArrayRef[Holistic::Person]',
    lazy => 1,
    default => sub { [ ] },
    traits => [ 'Array' ],
    handles => {
        'all_requestors' => 'elements',
        'add_requestor'  => 'push',
    }
);

has 'cc' => (
    is     => 'rw',
    isa    => 'ArrayRef[Holistic::Person]',
    traits => [ 'Array' ],
    lazy => 1,
    default => sub { [ ] },
    handles => {
        'all_cc' => 'elements',
        'add_cc' => 'push',
    }
);

has 'attention' => (
    is     => 'rw',
    isa    => 'ArrayRef[Holistic::Person]',
    traits => [ 'Array' ],
    lazy => 1,
    default => sub { [ ] },
    handles => {
        'all_attention' => 'elements',
        'add_attention' => 'push',
    }
);



no Moose;
__PACKAGE__->meta->make_immutable;
