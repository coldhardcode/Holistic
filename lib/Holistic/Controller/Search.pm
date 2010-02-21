package Holistic::Controller::Search;

use parent 'Catalyst::Controller';

use Moose;

use Data::SearchEngine::Holistic;
use Data::SearchEngine::Holistic::Query;

sub base : Chained('../search') PathPart('search') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

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

    $c->stash->{results} = $search->search($query);
    use Data::Dumper;
    $c->log->error(Dumper($c->stash->{results}->facets));
    $c->log->error(Dumper($c->stash->{results}->get_sorted_facet('status')));
    $c->stash->{template} = 'search/default.tt';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
