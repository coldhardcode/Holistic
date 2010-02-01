package Holistic::Controller::Queue;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'queue' } },
    class      => 'Schema::Queue',
    rs_key     => 'queue_rs',
    object_key => 'queue',
);

=head1 NAME

Holistic::Controller::Queue - Catalyst Controller

=cut

sub post_create : Private {
    my ( $self, $c, $data, $queue ) = @_;
    $queue->due_date( $data->{date_due} );
    if ( $data->{tags} ) {
        $queue->tag(map { $_ =~ s/^\s*|\s*//g; $_; } split(/,/, $data->{tags}));
    }
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
