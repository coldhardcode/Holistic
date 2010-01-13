package Holistic::Base::DBIx::Class;

use parent 'DBIx::Class';

__PACKAGE__->load_components( qw|TimeStamp EncodedColumn Core| );

1;
