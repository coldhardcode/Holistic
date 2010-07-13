package Holistic::Controller::Search;

use parent 'Catalyst::Controller';

use Moose;

use Data::SearchEngine::Holistic;
use Data::SearchEngine::Holistic::Query;

sub base : Chained('.') PathPart('search') CaptureArgs(0) { }

sub default : Chained('base') PathPart('') Args(0) {
    my ($self, $c) = @_;

    my $search = Data::SearchEngine::Holistic->new(
        schema => $c->model('Schema')->schema
    );

    my $q = $c->req->params->{search};
    my $query = Data::SearchEngine::Holistic::Query->new(
        original_query => $q,
        query => $q,
        page => $c->req->params->{page} || 1,
        count => $c->req->params->{count} || 10,
    );

    my @filters = qw(status priority type date_on);
    foreach my $filter (@filters) {
        my $val = $c->req->params->{$filter};
        next unless $val;
        $query->set_filter($filter, $c->req->params->{$filter});
    }

    $c->stash->{results} = $search->search($query);
    $c->stash->{template} = 'search/default.tt';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
