package Data::SearchEngine::Holistic::ChangeItem;
use Moose;

extends 'Data::SearchEngine::Item';

has change => (
    is => 'ro',
    isa => 'Holistic::Schema::Ticket::Change',
    handles => [ qw(ticket) ]
);

has classification => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        if($self->change->name eq 'resolution') {
            return 'closed';
        } elsif($self->change->name eq 'status') {
            return 'created';
        }
        return 'modified';
    }
);

1;