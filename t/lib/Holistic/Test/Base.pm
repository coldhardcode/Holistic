package Holistic::Test::Base;

use Moose::Role;

use Carp;
use Test::More;
use Try::Tiny;

use MooseX::MethodAttributes::Role;

sub run {
    my ( $self ) = @_;

    my $plan  = 0;
    my @tests = ();

    foreach my $method ( $self->meta->get_all_method_names ) {
        my $m = $self->meta->get_method($method);
        next unless $m->can('attributes');
        my $attrs = $m->attributes;
        if ( $attrs and ref $attrs eq 'ARRAY' ) {
            foreach my $attr ( @$attrs ) {
                if ( $attr =~ /^Plan\s*\(\s*(\d+)\s*\)\s*$/ ) {
                    $plan += $1;
                    try {
                        $self->$method();
                    } catch {
                        carp $_;
                    };
                }
            }
        }
    }

    done_testing( $plan );
}

no Moose::Role;
1;
