package Holistic::Application;
use Moose;
use Bread::Board;
use Data::Dumper;

extends 'Bread::Board::Container';

use MongoDB::Connection;

has 'database_host' => (
    is => 'ro',
    isa => 'Str',
    default => 'localhost'
);

has 'database_port' => (
    is => 'ro',
    isa => 'Int',
    default => 27017
);

sub BUILD {
    my ($self) = @_;

    container $self => as {

        container 'Database' => as {

            service 'host' => $self->database_host;
            service 'port' => $self->database_port;

            service 'connection' => (
                lifecycle => 'Singleton',
                block => sub {
                    my $s = shift;
                    print Dumper($s);
                    MongoDB::Connection->new(
                        host => $s->param('host'),
                        port => $s->param('port')
                    );
                },
                dependencies => [qw(host port)]
            );
        }
    };
}

1;