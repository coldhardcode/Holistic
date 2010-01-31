package Holistic::Base::DBIx::Class;

use Moose;
use MooseX::Types::DateTime 'DateTime';

use Data::Verifier;

extends 'DBIx::Class';

__PACKAGE__->load_components( qw|TimeStamp EncodedColumn Core| );

sub schema { shift->result_source->schema; }
sub resultset { shift->result_source->schema->resultset(@_); }

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
    my ( $self, $data ) = @_;

    my $profile = $self->_verify_profile;
    Data::Verifier->new( %$profile );
}

sub _build__verify_profile {
    my ( $self ) = @_;

    my $profile = {};
    foreach my $column ( $self->columns ) {
        my $info = $self->column_info( $column );
        next if $info->{is_auto_increment};

        my %parts = ();

        my $type = 'Str';
        if ( $info->{extra}->{verify_properties} ) {
            %parts = %{ $info->{extra}->{verify_properties} };
        }
        if ( $parts{type} ) {
            # No op, coming from verify_properties
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
            $parts{coerce} = 1;
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
        if ( exists $info->{default_value} ) {
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

1;
