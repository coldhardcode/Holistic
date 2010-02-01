package Holistic::Controller::Chart;

use parent 'Catalyst::Controller';

use Moose;

use Chart::Clicker;
use Chart::Clicker::Context;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Renderer::Pie;
use Geometry::Primitive::Rectangle;
use Graphics::Color::RGB;

sub base : Chained('../chart') PathPart('chart') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

sub completion_pie : Chained('base') PathPart('completion_pie') Args(1) {
    my ($self, $c, $percent) = @_;

    if($percent > 100) {
        $percent = 100;
    }

    my $uncomplete = 100 - $percent;

    my $cc = Chart::Clicker->new(width => 16, height => 16);

    my $ds = Chart::Clicker::Data::DataSet->new;
    $ds->add_to_series(Chart::Clicker::Data::Series->new(
        keys    => [ 1, 2 ],
        values  => [ 0, $percent],
    ));
    if($uncomplete) {
        $ds->add_to_series(Chart::Clicker::Data::Series->new(
            keys    => [ 1, 2 ],
            values  => [ 0, $uncomplete ],
        ));
    }

    # my $ds = Chart::Clicker::Data::DataSet->new(series => [ $series1, $series2 ]);

    my $blue = Graphics::Color::RGB->new(red => .20, green => .44, blue => .66);
    my $gray = Graphics::Color::RGB->new(red => .87, green => .87, blue => .87);
    $cc->color_allocator->colors([
        $blue, $gray
    ]);

    $cc->add_to_datasets($ds);
    $cc->background_color($gray);
    $cc->padding(0);

    my $defctx = $cc->get_context('default');
    my $pie = Chart::Clicker::Renderer::Pie->new;
    $pie->brush->width(1);
    $defctx->renderer($pie);
    $defctx->domain_axis->hidden(1);
    $defctx->range_axis->hidden(1);
    $cc->plot->grid->visible(0);
    $cc->legend->visible(0);
    $cc->border->width(0);

    $c->stash->{graphics_primitive} = $cc;
    $c->forward( $c->view('GP') );
}

no Moose;
__PACKAGE__->meta->make_immutable;



1;
