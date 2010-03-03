package Holistic::Test::Search;

use Test::More;
use Moose::Role;
use MooseX::MethodAttributes::Role;

use Try::Tiny;

use Data::SearchEngine::Holistic;
use Data::SearchEngine::Holistic::Query;

with 'Holistic::Test::Schema'; # We require schema

has 'searcher' => (
    is => 'rw',
    lazy_build => 1,
    handles => {
        'search' => 'search'
    }
);

sub _build_searcher {
    Data::SearchEngine::Holistic->new( schema => shift->schema );
}

sub do_search : Plan(1) {
    my ( $self, $data ) = @_;

    my $q     = $data->{query} || 'test';
    my $page  = 1;
    my $count = 10;

    my $query = Data::SearchEngine::Holistic::Query->new(
        original_query  => $q,
        query           => $q,
        page            => $page,
        count           => $count
    );

    my $results = $self->search( $query );
    ok($results, 'got results');

    if(exists($data->{count})) {
        cmp_ok($results->pager->total_entries, '==', $data->{count}, 'total entries = '.$data->{count});
    }
}

1;
