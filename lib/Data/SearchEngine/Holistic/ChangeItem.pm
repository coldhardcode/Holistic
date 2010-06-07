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
	    } elsif($self->change->name eq 'advanced') {
	        return 'advanced';
        } elsif($self->change->name eq 'created') {
            return 'created';
        } elsif($self->change->name eq 'closed') {
			return 'closed';
		}
        return 'modified';
    }
);

1;