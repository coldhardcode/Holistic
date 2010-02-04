package Holistic::Controller::Search;

use parent 'Catalyst::Controller';

use Moose;

use Data::SearchEngine::Holistic;
use Data::SearchEngine::Query;

sub base : Chained('../search') PathPart('search') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

sub default : Chained('base') PathPart('') Args(0) {
    my ($self, $c) = @_;

    my $q = $c->req->params->{search};
    my $query = Data::SearchEngine::Query->new(
        original_query => $q,
        query => $q,
        page => $c->req->params->{page} || 1,
        count => $c->req->params->{count} || 10
    );

    $c->stash->{results} = Data::SearchEngine::Holistic->new->search($query);
    $c->stash->{template} = 'search/default.tt';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
