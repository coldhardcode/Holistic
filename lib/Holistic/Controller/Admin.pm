package Holistic::Controller::Admin;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions     => { 'setup' => { PathPart => 'admin' } },
    permissions => {
        # Just to get to this point in the chain, we require this:
        'setup' => [ 'ADMIN' ]
    },
    allow_by_default => 0
);

=head1 NAME

Holistic::Controller::Admin - Controller for admin actions

=head1 DESCRIPTION

This is mostly a stub controller used for just checking permissions.

=head1 METHODS

=cut

after 'setup' => sub {
    my ($self, $c) = @_;

    push(@{ $c->stash->{page}->{crumbs} }, { 'Admin' => $c->uri_for_action('/admin/root')->as_string });
};

sub root : Chained('setup') PathPart('') Args(0) { }
sub object {} # We don't have objects, clobber what REST puts in
sub _fetch_rs { undef; }

sub settings : Chained('setup') Args(0) { }

sub group   : Chained('setup') PathPart('') CaptureArgs(0) { }
sub person  : Chained('setup') PathPart('') CaptureArgs(0) { }
sub product : Chained('setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
