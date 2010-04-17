package Holistic::Base::DBIx::Class;

use Moose;
use MooseX::Types::DateTime 'DateTime';
use DateTime::Format::MySQL;
use Try::Tiny;
use Data::Verifier;

extends 'DBIx::Class';

__PACKAGE__->load_components( qw|TimeStamp EncodedColumn Core| );

sub schema { shift->result_source->schema; }
sub resultset { shift->result_source->schema->resultset(@_); }

1;
