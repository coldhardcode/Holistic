package Holistic::Controller::Admin;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

Holistic::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub setup : Chained('.') PathPart('admin') CaptureArgs(0) {
    my ($self, $c) = @_;

    push(@{ $c->stash->{page}->{crumbs} }, { 'Admin' => $c->uri_for_action('/admin/root')->as_string });
}

sub root : Chained('setup') PathPart('') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{holistic_version} = $Holistic::VERSION;
    $c->stash->{template} = 'admin/root.tt';
}

sub settings : Chained('setup') PathPart('settings') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/settings.tt';
}

sub group   : Chained('setup') PathPart('') CaptureArgs(0) { }
sub person  : Chained('setup') PathPart('') CaptureArgs(0) { }
sub product : Chained('setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
