package Holistic::Test::Base;

use Moose::Role;

use Carp;
use Test::More;
use Try::Tiny;

use MooseX::MethodAttributes::Role;

has 'planned_tests' => (
    is  => 'rw',
    isa => 'Int',
    default => 0
);

sub run {
    my ( $self, $methods ) = @_;

    my $plan  = 0;
    my @tests = ();

    my @method_names = ( defined $methods and @$methods > 0 ) ?
        @$methods : $self->meta->get_all_method_names;

    foreach my $method ( @method_names ) {
        my $call_args = {};

        if ( ref $method eq 'HASH' ) {
            ( $method, $call_args ) = each %$method;
        }
        $self->run_test( $method, $call_args );
     }

    done_testing( $self->planned_tests );
}

sub run_test {
    my ( $self, $method, $call_args ) = @_;
    
    my $m = $self->meta->get_method($method);
    unless ( defined $m ) {
        confess "Unknown method name: $method, check test plan.";
    }

    next unless $m->can('attributes');
    my $attrs = $m->attributes;
    if ( $attrs and ref $attrs eq 'ARRAY' ) {
        foreach my $attr ( @$attrs ) {
            if ( $attr =~ /^Plan\s*\(\s*(\d+)\s*\)\s*$/ ) {
                $self->planned_tests( $self->planned_tests + $1 );
                try {
                    $self->$method($call_args);
                } catch {
                    confess $_;
                };
            }
        }
    }
}

no Moose::Role;
1;
