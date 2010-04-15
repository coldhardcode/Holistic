package Holistic;
use Moose;
use namespace::autoclean;
use Scalar::Util 'blessed';

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    ConfigLoader Params::Nested

    I18N Unicode
    Static::Simple

    Authentication
    Session Session::Store::FastMmap Session::State::Cookie

    Cache

    +Holistic::Plugin::Message
/;

extends 'Catalyst';

# TraitFor is being a bitch
use Catalyst::Request::REST::ForBrowsers;
Holistic->request_class( 'Catalyst::Request::REST::ForBrowsers' );

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in holistic.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Holistic',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    default_view => 'TT',
    'Plugin::Cache' => {
        backend => { class => 'Cache::FastMmap' }
    },
    'Plugin::Authentication' => {
        default_realm => 'progressive',
        realms => {
            progressive => {
                class => 'Progressive',
                realms => [ 'temp', 'local', 'rpx' ],
                authinfo_munge => {
                    'local'     => { 'realm' => 'local' },
                    'temp'      => { 'realm' => 'temp' },
                    'rpx'       => { 'realm' => 'rpx' },
                }
            },
            rpx => {
                credential => {
                    class           => 'Password',
                    password_field  => 'secret',
                    password_type   => 'hashed',
                    password_hash_type => 'SHA-1',
                },
                store => {
                    class       => 'DBIx::Class',
                    user_class  => 'Schema::Person::Identity',
                    id_field    => 'ident',
                }
            }, 
            local => {
                credential => {
                    class               => 'Password',
                    password_field      => 'secret',
                    self_check          => 1,
                },
                store => {
                    class       => 'DBIx::Class',
                    user_class  => 'Schema::Person::Identity',
                    id_field    => 'ident',
                }
            },
            temp => {
                credential => {
                    class => 'Password',
                    password_field => 'secret',
                    self_check          => 1,
                },
                store => {
                    class    => 'DBIx::Class',
                    user_class => 'Schema::Person::Identity',
                    id_field   => 'ident',
                }
            },
        }
    },
);

# Start the application
__PACKAGE__->setup();

sub tt_ref { my ( $c, $item ) = @_; ref($item); }
sub tt_isa { my ( $c, $item, $isa ) = @_; blessed $item && $item->isa($item); }
sub tt_blessed { my ( $c, $item ) = @_; blessed $item; }

=head1 NAME

Holistic - Catalyst based application

=head1 SYNOPSIS

    script/holistic_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Holistic::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
