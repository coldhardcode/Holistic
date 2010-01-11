package Holistic::Schema;

use Moose;

extends 'DBIx::Class::Schema';

use Carp;

our $VERSION = '0.01';

__PACKAGE__->load_namespaces(
    result_namespace        => '+Holistic::Schema',
    default_resultset_class => '+Holistic::Base::ResultSet'
);

use Text::xSV;

sub deploy {
    my ( $self, $properties ) = @_;
    
    my $data_import = delete $properties->{import};

    my $key_check_off;
    my $key_check_on;

    if ( $self->storage->connect_info->[0] =~ /^DBI:mysql/i ) {
        $key_check_off = "SET FOREIGN_KEY_CHECKS = 0;";
        $key_check_on  = "SET FOREIGN_KEY_CHECKS = 1;";
    }

    my $populate_txn = sub {
        $self->SUPER::deploy($properties, @_);

        return unless $data_import and ref $data_import eq 'HASH';
        $self->storage->dbh->do($key_check_off) if $key_check_off;

        foreach my $data ( keys %$data_import ) {
            my $rs = $self->resultset($data);
            unless ( $rs ) {
                carp "Unknown result set in import: $data"
            }
            my $csv = Text::xSV->new;
            $csv->open_file($data_import->{$data});
            $csv->read_header;
            foreach my $field ( $csv->get_fields ) {
                if ( lc($field) ne $field ) {
                    $csv->alias($field, lc($field));
                }
            }

            while ( my $row = $csv->fetchrow_hash ) {
                eval { $rs->create($row); };
                if ( $@ ) {
                    die "Unable to insert row from data: " . join(', ', values %$row) . "\n\t$@\n";
                }
            }
        }
        $self->storage->dbh->do($key_check_on) if $key_check_on;
    };
    $self->txn_do( $populate_txn );
    if ( $@ ) {
        die "Unable to deploy and populate data: $@";
    }
}

sub tokenize {
    my ( $field ) = @_;
    $field = lc($field);
    $field =~ s/&/-/g;
    $field =~ s/\s+/_/g;
    $field =~ s/[^\w\-]/_/g;
    $field =~ s/_+/_/g;
    return $field;
}

=head1 SYNOPSIS

This is the core Holistic::Schema class, which is simply an augmented
L<DBIx::Class::Schema> implementation.

=head1 METHODS

=head2 deploy

The deploy method accepts a hash reference as a parameter, with handling of
an C<import> key for loading data from CSV files and importing into the 
database.

The syntax of the import hash ref is simple, in that the ResultSet name is the
hash key and the value is the path to the file.

 $schema->deploy({
     import => {
         SomeResultSet => "/path/to/data.csv"
     }
 });

This is imported inside of a transaction, and any failure will abort the 
deployment.

=head1 AUTHOR

J. Shirley <jshirley@coldhardcode.com>

=cut

1;
