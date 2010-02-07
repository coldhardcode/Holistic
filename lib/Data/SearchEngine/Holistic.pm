package Data::SearchEngine::Holistic;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Results;

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    for(1..5) {
        push(@items, Data::SearchEngine::Item->new(
            id => 'X',
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