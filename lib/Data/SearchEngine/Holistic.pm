package Data::SearchEngine::Holistic;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Holistic::Results;

has schema => (
    is => 'ro',
    required => 1
);

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    my $rs = $self->schema->resultset('Ticket')->search(
        {
            '-or' => [
                name => { -like => '%'.$oquery->query.'%' },
                description => { -like => '%'.$oquery->query.'%' }
            ]
        }, {
        }
    );

    my %facets = ();
    while(my $tick = $rs->next) {

        my $products = $tick->products;
        while(my $prod = $products->next) {
            $facets{product}->{$prod->name}++;
        }

        $facets{status}->{$tick->status->name}++;
        $facets{owner}->{$tick->owner->person->token}++;
        $facets{priority}->{$tick->priority->name}++;
        $facets{type}->{$tick->type->name}++;

        push(@items, Data::SearchEngine::Holistic::Item->new(
            id => $tick->id,
            ticket => $tick,
            score => 1
        ));
    }

    my $results = Data::SearchEngine::Holistic::Results->new(
        query => $oquery,
        pager => Data::SearchEngine::Paginator->new(
            entries_per_page => $oquery->count,
            total_entries => scalar(@items)
        ),
        items => \@items,
        elapsed => time - $start,
        facets => \%facets
    );
}

1;