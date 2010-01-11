package Holistic::Roles::Environment;

use Moose::Role;
use MooseX::Types::Path::Class qw/File Dir/;

use FindBin;
use Data::Visitor::Callback;
use Scalar::Util qw(blessed);
use Hash::Merge;
use Carp;

has configfile => (
    is => 'ro',
    isa => File,
    coerce => 1,
    predicate => 'has_configfile',
);

has 'approot' => (
    is         => 'rw',
    isa        => Dir,
    coerce     => 1,
    default    => sub { Path::Class::Dir->new( $FindBin::Bin )->parent }
);

has config => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } }
);

# We're using the app root as both a class and instance attribute,
# so we do this.  I'm sure this is wrong.
sub _get_app_root {
    my ( $self ) = @_;
    my $approot = $self->meta->get_attribute('approot');
    return $approot->default->($self);
}

sub path_to {
    my ( $self, @path ) = @_;

    my $root = $self->_get_app_root;

    if ( @path > 1 ) {
        my $file = pop @path;
        return $self->path_to_dir( @path )->file($file);
    } elsif ( $path[0] ) {
        return $root->file($path[0]);
    }
    return $root;
}

sub path_to_dir {
    my ( $self, @path ) = @_;
    my $dir = $self->_get_app_root->subdir(@path);

    return $dir;
}

sub config_substitutions {
    my $c    = shift;
    my $subs = $c->config->{ 'Plugin::ConfigLoader' }->{ substitutions }
        || {};
    $subs->{HOME} ||= sub { shift->path_to( '' ); };
    $subs->{ENV}  ||=
        sub {
            my ( $c, $v ) = @_;
            if (! defined($ENV{$v})) {
                croak "Missing environment variable: $v";
            } else {
                return $ENV{ $v };
            }
        };
    $subs->{path_to} ||= sub { shift->path_to( @_ ); };
    $subs->{literal} ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $c, $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

sub new_with_config {
    my ( $class, %opts ) = @_;

    my $configfile;

    if ( defined $opts{configfile} ) {
        $configfile = $opts{configfile}
    }
    else {
        my $cfmeta = $class->meta->get_attribute('configfile');
        $configfile = $cfmeta->default if $cfmeta->has_default;
        if ( ref $configfile eq 'CODE' ) {
            $configfile = $configfile->($class);
        }
    }
    if ( defined $configfile ) {
        %opts = ( 
            %{$class->get_config_from_file($configfile)},
            %opts
        );
    }

    my $obj = $class->new(%opts);
    $obj->config( $obj->finalize_config( \%opts ) );

    return $obj;
}

sub get_config_from_file {
    my ( $self, $file ) = @_;
    my $data = {};
    if ( -f $file ) {
        $data = YAML::XS::LoadFile($file);
    }
    return $data;
}

sub finalize_config {
    my ( $self, $data ) = @_;
    my $v = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            $self->config_substitutions( $_ );
        }
    );
    $v->visit( $data );
    return $data;
}

no Moose::Role;
1;
