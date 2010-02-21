package Data::SearchEngine::Holistic;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Results;

has schema => (
    is => 'ro',
    required => 1
);

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    my $rs = $self->schema->resultset('Ticket')->search(undef, { page => $oquery->page, rows => $oquery->count });
    while(my $tick = $rs->next) {
        push(@items, Data::SearchEngine::Holistic::Item->new(
            id => $tick->id,
            ticket => $tick,
            score => 1
        ));
    }

    return Data::SearchEngine::Results->new(
        query => $oquery,
        pager => Data::SearchEngine::Paginator->new(
            entries_per_page => $oquery->count,
            total_entries => scalar(@items)
        ),
        items => \@items,
        elapsed => time - $start
    );
}

1;