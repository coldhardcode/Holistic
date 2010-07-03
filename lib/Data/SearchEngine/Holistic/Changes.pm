package Data::SearchEngine::Holistic::Changes;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::ChangeItem;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Holistic::Results;
use Hash::Merge qw(merge);
use Search::QueryParser;

has schema => (
    is => 'ro',
    required => 1
);

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    my $full_rs = $self->schema->resultset('Ticket::Change')->search(undef, {
        join => {
			ticket => [ 'queue', { identity => 'person' } ],
			identity => 'person'
		}
    });

    $full_rs = $self->_apply_filters($full_rs, $oquery);

    my $changes = $full_rs->search(undef, {
        page => $oquery->page, rows => $oquery->count,
        order_by => [ { -desc => 'me.dt_created' }, 'position' ],
        group_by => 'changeset'
    });

    my $pager = Data::SearchEngine::Paginator->new(
        current_page => $oquery->page,
        entries_per_page => $oquery->count,
        total_entries => $full_rs->count
    );

    my $faceter = DBIx::Class::ResultSet::Faceter->new;
    $faceter->add_facet('Column', { name => 'date_on', column => 'dt_created.ymd' });
    $faceter->add_facet('Column', { name => 'owner', column => 'identity.person.name' });
    $faceter->add_facet('Column', { name => 'queue_name', column => 'top_queue.name' });

    my $fac_res = $faceter->facet($full_rs);

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
        facets => $fac_res->facets
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
        } elsif($filter eq 'queue_name') {
			my $path = $oquery->get_filter('queue_name');
			# Convert dots to underscores for paths.
			$path =~ s/\./_/;
			# Not the dot added in front of the path.  That makes it less
			# likely that this will accidentally pick something up since the
			# path elements are separated by dots.
			$rs = $rs->search({ 'queue.path' => { -like => "\%.$path\%" } });
		}
    }

    return $rs;
}

__PACKAGE__->meta->make_immutable;

1;
