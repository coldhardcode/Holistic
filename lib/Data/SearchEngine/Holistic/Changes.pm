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
            owner => {
                alias => 'person',
                text => 1,
                field => 'token'
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
    my $full_rs = $self->schema->resultset('Ticket::Change')->search(undef, {
        prefetch => [ 'ticket' => { identity => 'person' }, { 'identity' => 'person' } ]
    });

    $full_rs = $self->_apply_filters($full_rs, $oquery);

    my $changes = $full_rs->search(undef, {
        page => $oquery->page, rows => $oquery->count,
        order_by => { -desc => 'me.dt_created' },
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

    # while(my $change = $full_rs->next) {
    #     $facets{owner}->{$change->identity->ident} = $prod_facet->get_column('product_count');
    # }
    # for(0..scalar(@tickets) - 1) {
    while(my $change = $full_rs->next) {
        # my $tick = $tickets[$_];

        # my $products = $tick->products;
        # while(my $prod = $products->next) {
        #     $facets{product}->{$prod->name}++;
        # }
        # 
        # $facets{status}->{$tick->status->name}++;
        $facets{date_on}->{$change->dt_created->ymd}++;
        $facets{owner}->{$change->identity->person->token}++;
        # $facets{priority}->{$tick->priority->name}++;
        # $facets{type}->{$tick->type->name}++;
    }

    while(my $change = $changes->next) {
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

sub _apply_filters {
    my ($self, $rs, $oquery) = @_;

    return $rs unless $oquery->has_filters;

    foreach my $filter ($oquery->filter_names) {
        if($filter eq 'date_on') {
            my $date = $oquery->get_filter('date_on');
            $rs = $rs->search({ 'me.dt_created' => { -between => [ $date.' 00:00:00', $date. ' 23:59:59' ] } });
        } elsif($filter eq 'owner') {
            $rs = $rs->search({ 'person.token' => $oquery->get_filter('owner') });
        }
    }

    return $rs;
}

__PACKAGE__->meta->make_immutable;

1;
