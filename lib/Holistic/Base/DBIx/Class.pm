package Holistic::Base::DBIx::Class;

use parent 'DBIx::Class';

__PACKAGE__->load_components( qw|TimeStamp EncodedColumn Core| );

sub schema { shift->result_source->schema; }
sub resultset { shift->result_source->schema->resultset(@_); }

1;
