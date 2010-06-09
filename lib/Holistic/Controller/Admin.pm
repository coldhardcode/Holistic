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

sub settings : Chained('setup') Args(0) ActionClass('REST') { }

sub settings_GET { }

sub settings_POST { 
    my ( $self, $c ) = @_;

    my $person = $c->stash->{system}->{identity}->person;

    my $data = $c->req->data || $c->req->params;
$c->log->_dump( $data );
    $person->save_metadata( $data );
$c->log->_dump( $person->metadata );

    if ( $c->req->looks_like_browser ) {
        $c->message($c->loc("System preferences have been updated"));
        $c->res->redirect($c->uri_for_action('/admin/root'));
    }
    elsif ( $c->req->header('x-requested-with') =~ /XMLHttpRequest/i ) {
        $c->stash->{page}->{layout} = 'partial';
        $c->stash->{system}->{settings} = $person->metadata;
        if ( $data->{walkthrough} eq "0" ) {
            $c->stash->{template} = 'site/nav/post-walkthrough.tt';
        }
    }
}

sub group   : Chained('setup') PathPart('') CaptureArgs(0) { }
sub person  : Chained('setup') PathPart('') CaptureArgs(0) { }
sub product : Chained('setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
