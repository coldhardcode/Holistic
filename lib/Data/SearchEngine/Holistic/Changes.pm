package Data::SearchEngine::Holistic::Changes;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::ChangeItem;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Holistic::Results;
use Hash::Merge qw(merge);
use Search::QueryParser;

has fields => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        {
            name => {
                alias => 'me',
                text => 1,
                field => 'name'
            },
            date_created => {
                alias => 'me',
                field => 'dt_created',
                text => 0
            },
            description => {
                alias => 'me',
                text => 1,
                field => 'description',
            },
            priority => {
                alias => 'priority',
                text => 1,
                field => 'name'
            },
            queue => {
                alias => 'me',
                text => 0,
                field => 'queue_pk1'
            },
            queue_name => {
                alias => 'queue',
                text => 1,
                field => 'name'
            },
            reporter => {
                alias => 'me',
                text => 1,
                field => 'identity_pk1'
            },
            reporter_email => {
                alias => 'person',
                text => 1,
                field => 'email'
            },
            reporter_name => {
                alias => 'person',
                text => 1,
                field => 'name'
            },
            type => {
                alias => 'type',
                text => 1,
                field => 'name'
            }
        }
    },
    lazy => 1
);

has schema => (
    is => 'ro',
    required => 1
);

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    my $full_rs = $self->schema->resultset('Ticket::Change');

    my $changes = $full_rs->search(undef, {
        page => $oquery->page, rows => $oquery->count
    });

    my $pager = Data::SearchEngine::Paginator->new(
        current_page => $oquery->page,
        entries_per_page => $oquery->count,
        total_entries => $full_rs->count
    );

    my %facets = ();

    # my $prod_facets = $tickets->search(undef, {
    #     group_by => 'product.pk1',
    #     join => { 'queue' => { 'product_links' => 'product' } },
    #     '+select' => [ \'product.name AS product_name', { count => 'product.pk1' } ],
    #     '+as' => [ 'product_name', 'product_count' ],
    #     order_by => \'product_count DESC',
    #     page => 1,
    #     rows => 5
    # });
    # while(my $prod_facet = $prod_facets->next) {
    #     $facets{product}->{$prod_facet->get_column('product_name')} = $prod_facet->get_column('product_count');
    # }
    # for(0..scalar(@tickets) - 1) {
        # my $tick = $tickets[$_];

        # my $products = $tick->products;
        # while(my $prod = $products->next) {
        #     $facets{product}->{$prod->name}++;
        # }
        # 
        # $facets{status}->{$tick->status->name}++;
        # $facets{owner}->{$tick->owner->person->token}++;
        # $facets{priority}->{$tick->priority->name}++;
        # $facets{type}->{$tick->type->name}++;

    print STDERR "### asdasda\n";
    while(my $change = $changes->next) {
        print STDERR "asdasda\n";
        push(@items, Data::SearchEngine::Holistic::ChangeItem->new(
            id => $change->id,
            change => $change,
            score => 1
        ));
    }

    my $results = Data::SearchEngine::Holistic::Results->new(
        query => $oquery,
        pager => $pager,
        items => \@items,
        elapsed => time - $start,
        facets => \%facets
    );
}

__PACKAGE__->meta->make_immutable;

1;
