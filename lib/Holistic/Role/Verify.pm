package Holistic::Role::Verify;

use Moose::Role;
use Data::Verifier;

has 'verify_scope' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy_build => 1,
);

has 'verifier' => (
    is          => 'ro',
    isa         => 'Data::Verifier',
    lazy_build  => 1,
    handles => {
        'verify' => 'verify'
    }
);

has '_verify_profile' => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
);

sub _build_verifier {
    my ( $self ) = @_;
    Data::Verifier->new( $self->_verify_profile );
}

sub _build__verify_profile {
    my ( $self ) = @_;

    my $profile = {};
    foreach my $column ( $self->columns ) {
        my $info = $self->column_info( $column );
        next if $info->{is_auto_increment};
        next if $info->{is_foreign_key};

        my %parts = ();

        my $type = 'Str';
        if ( $info->{extra}->{verify_properties} ) {
            %parts = %{ $info->{extra}->{verify_properties} };
        }
        if ( $parts{type} ) {
            # No op, coming from verify_properties
        }
        # Skip if we have a dynamic setup
        elsif ( $info->{set_on_create} or
                $info->{set_on_update} or
                $info->{dynamic_default_on_create} or
                $info->{dynamic_default_on_update}
        ) {
            next;
        }
        elsif ( $info->{data_type} =~ /^text|varchar|char$/ ) {
            $type = 'Str';
            if ( exists $info->{size} ) {
                $parts{max_length} = $info->{size};
            }
            $parts{min_length} = 1;
        }
        elsif ( $info->{data_type} =~ /^date|datetime$/ ) {
            $type = 'DateTime';
            my $method = "parse_$info->{data_type}";
            $parts{coercion} = Data::Verifier::coercion(
                from => 'Str',
                via  => sub {
                    my $fmt = $_;
                    my $dt;
                    try {
                        $dt = DateTime::Format::MySQL->$method($fmt);
                    } catch {
                        $dt = DateTime::Format::MySQL->parse_date($fmt);
                    };
                    $dt;
                }
            );
        }
        elsif ( $info->{data_type} =~ /^int|integer$/ ) {
            $type = 'Int';
        }
        elsif ( $info->{data_type} =~ /^double|float|decimal$/ ) {
            $type = 'Num';
        }
        my $required = 1;
        $required = 0 if $info->{is_nullable};
        $required = 0 if $info->{dynamic_default_on_create};
        if ( defined $info->{default_value} ) {
            $required = 0;
            $parts{default} = $info->{default_value};
        }
        $profile->{$info->{accessor} || $column} = {
            %parts,
            type     => $type,
            required => $required,
        };
    }

    return { filters => [ qw(trim) ], profile => $profile };
}

no Moose::Role;
1;
