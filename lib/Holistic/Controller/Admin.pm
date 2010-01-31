package Holistic::Controller::Admin;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

Holistic::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


sub setup : Chained('../admin') PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;

    push(@{ $c->stash->{page}->{crumbs} }, { 'Admin' => '/admin' });
}

sub default : Chained('setup') PathPart('') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/default.tt';
}

sub group : Chained('setup') PathPart('group') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/group.tt';
}

sub group_management : Chained('setup') PathPart('group_management') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/group_management.tt';
}

sub product : Chained('setup') PathPart('product') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/product.tt';
}

sub settings : Chained('setup') PathPart('settings') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/settings.tt';
}



no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
