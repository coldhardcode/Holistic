package Holistic::Plugin::Message;

use warnings;
use strict;

use Class::C3;

our $VERSION = '0.01';

=head1 NAME

Holistic::Plugin::Message

=head1 DESCRIPTION

This plugin offers persistent messaging (and does require the Session plugin)
that gracefully handles any redirects (so you can happily use GET after POST).

The messages are always accessible via the stash while the view is rendered,
regardless of the number of redirects.

It stores the messages in a simple list, in the stash.  The structure is as 
follows:

 [
     { type => 'info', message => 'message text here' },
     { type => 'info', message => 'message text here' },
     ...
 ]

=head1 CONFIGURATION

For message storage, there are two configuration options: C<stash_key> and 
C<flash_key>.  This define the locations in the stash to place the messages.

To define the default type, for calling C<< $c->message('Simple Syntax') >> set
the C<default_type> configuration key.

 package MyApp;

 use Catalyst qw/+Greenspan::Plugin::Message/;

 __PACKAGE__->config({
     'Plugin::Message' => {
         stash_key => 'messages',
         flash_key => '_message',
         default_type => 'info',
     }
 });

=head1 METHODS

=head2 message($message)

Add a new message to the stack.  The message can be a simple scalar value, which
is created as an informational type.  Alternatively, if you want a different
type attriute, simply call C<< $c->message >> in this form:

 $c->message({
     type    => 'error',
     message => 'Your message string here'
 });

Called without any arguments, it simply returns the current message stack

=cut

sub message {
    my ( $c, $message ) = @_;

    my $default   = $c->config->{'Plugin::Message'}->{default_type} || 'info';
    my $stash_key = $c->config->{'Plugin::Message'}->{stash_key} || 'messages';
    $c->stash->{$stash_key} ||= [];
    my $stash = $c->stash->{$stash_key};

    return $stash unless $message;

    my $s = {};
    if ( ref $message ) {
        $s->{type}    = $message->{type} || $default;
        $s->{message} = $message->{message};
    } else {
        $s->{type}    = $default;
        $s->{message} = $message;
    }
    if ( $s->{type} and $s->{message} ) {
        push @{ $stash }, $s;
    }
    return $stash;
}

sub dispatch {
    my $c   = shift;

    my $stash_key = $c->config->{'Plugin::Message'}->{stash_key} || 'messages';
    my $flash_key = $c->config->{'Plugin::Message'}->{flash_key} || '_messages';

    # Copy to the stash
    if ( $c->can('flash') and $c->flash->{$flash_key} ) {
        $c->stash->{$stash_key} = $c->flash->{$flash_key};
    }
    my $ret = $c->next::method(@_);

    # Redirect?
    my $messages = $c->stash->{$stash_key};
    if ( $messages and @$messages and $c->response->location ) {
        push @{$c->flash->{$flash_key}}, @$messages;
    }
    return $ret;
}

=head1 AUTHOR

J. Shirley C<< <j@shirley.im> >>

=cut

1;
