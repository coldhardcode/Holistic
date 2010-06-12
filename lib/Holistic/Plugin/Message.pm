package Holistic::Plugin::Message;

use warnings;
use strict;

use Message::Stack;
use MRO::Compat;
use Scalar::Util 'blessed';

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
         default_type => 'warning',
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

    my $default   = $c->config->{'Plugin::Message'}->{default_type} || 'success';
    my $stash_key = $c->config->{'Plugin::Message'}->{stash_key} || 'messages';
    $c->stash->{$stash_key} ||= Message::Stack->new;
    my $stash = $c->stash->{$stash_key};

    return $stash unless $message;

    if ( blessed $message ) {
        $stash->add($message);
    } else {
        my $s = { scope => 'global' };
        if ( ref $message ) {
            $s->{level}   = $message->{type} || $default;
            $s->{id}      = $message->{message};
            $s->{scope}   = $message->{scope} || 'global';
        } else {
            $s->{level}   = $default;
            $s->{id}      = $message;
        }
        $stash->add($s);
    }

    $c->stash->{$stash_key} = $stash;

    return $stash;
}


sub has_messages {
    my ( $c, $scope ) = @_;

    my $stash_key = $c->config->{'Plugin::Message'}->{stash_key} || 'messages';
    my $stack = $c->stash->{$stash_key};
    return 0 unless defined $stack;

    if ( $scope ) {
        return $stack->for_scope($scope)->has_messages;
    }
    return $stack->has_messages;
}

sub dispatch {
    my $c   = shift;

    my $stash_key = $c->config->{'Plugin::Message'}->{stash_key} || 'messages';
    my $flash_key = $c->config->{'Plugin::Message'}->{flash_key} || '_messages';

    # Copy to the stash
    if ( $c->can('flash') and $c->flash->{$flash_key} ) {
        $c->stash->{$stash_key} = delete $c->flash->{$flash_key};
    }

    my $ret = $c->next::method(@_);

    return $ret unless defined $c->res->location;

    # Redirect?
    my $messages = $c->stash->{$stash_key};
    return $ret unless defined $messages;

    if ( $messages->has_messages and $c->response->location) {
        $c->flash->{$flash_key} = $messages;
    }
    return $ret;
}

=head1 AUTHOR

J. Shirley C<< <j@shirley.im> >>

=cut

1;
