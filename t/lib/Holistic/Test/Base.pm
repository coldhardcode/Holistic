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

has 'use_plan' => (
    is => 'rw',
    isa => 'Int',
    default => 1
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

    if ( $self->use_plan ) {
        done_testing( $self->planned_tests );
    } else {
        done_testing;
    }
}

sub run_test {
    my ( $self, $method, $call_args ) = @_;
    
    my $m = $self->meta->get_method($method);
    unless ( defined $m ) {
        confess "Unknown method name: $method, check test plan.";
    }

    warn "$method does not define a test plan" unless $m->can('attributes');
    my $attrs = $m->attributes;
    my $ret   = undef;
    if ( $attrs and ref $attrs eq 'ARRAY' ) {
        foreach my $attr ( @$attrs ) {
            diag(" --> Running " . $m->original_package_name . "->$method");
            if ( $attr =~ /^Plan\s*\(\s*(\d+)\s*\)\s*$/i ) {
                $self->planned_tests( $self->planned_tests + $1 );
                try {
                    $ret = $self->$method($call_args);
                } catch {
                    confess $_;
                };
            }
            elsif ( lc($attr) eq 'test' ) {
                $self->use_plan(0);
                try {
                    $ret = $self->$method($call_args);
                } catch {
                    confess $_;
                };
            }
        }
    }

    return $ret;
}

no Moose::Role;
1;
