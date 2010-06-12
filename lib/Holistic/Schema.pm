package Holistic::Schema;

use Moose;

extends 'DBIx::Class::Schema';

use Carp;

our $VERSION = '0.01';

__PACKAGE__->load_namespaces(
    result_namespace        => '+Holistic::Schema',
    default_resultset_class => '+Holistic::Base::ResultSet'
);

has 'data_manager' => (
    is  => 'rw',
    isa => 'Holistic::DataManager',
    lazy_build => 1,
    handles => {
        'resultsource_for_scope' => 'resultsource_for_scope',
        'data_for_scope'         => 'data_for_scope',
    }
);

sub _build_data_manager {
    my ( $self ) = @_;

    my $verifiers = {};
    my $scopes    = {};
    foreach my $name ( $self->sources ) {
        my $source = $self->resultset($name)->new_result({});
        next unless $source->can('meta');
        next unless $source->meta->does_role('Holistic::Role::Verify');
        $verifiers->{$source->verify_scope} = $source->verifier;
        $scopes->{ $source->verify_scope }  = "Schema::$name";
    }

    Holistic::DataManager->new(
        verifiers             => $verifiers,
        scope_to_resultsource => $scopes
    );
}

use Text::xSV;

sub deploy {
    my ( $self, $properties ) = @_;
    
    my $data_import = delete $properties->{import};

    my $key_check_off;
    my $key_check_on;

    if ( $self->storage->connect_info->[0] =~ /^DBI:mysql/i ) {
        $properties->{add_drop_table} = 1
            unless exists $properties->{add_drop_table};
        $key_check_off = "SET FOREIGN_KEY_CHECKS = 0;";
        $key_check_on  = "SET FOREIGN_KEY_CHECKS = 1;";
    }

    my $populate_txn = sub {
        $self->SUPER::deploy($properties, @_);

        $self->storage->dbh->do($key_check_off) if $key_check_off;

        my $system_person = $self->resultset('Person')->create({
            name  => 'Holistic System User',
            token => 'holistic',
            email => 'no-reply@coldhardcode.com',
        });
        my $system_ident = $system_person->add_to_identities({
            realm  => 'system',
            ident  => 'system',
            active => 0
        });

        $self->resultset('Comment')->create({
            pk1          => 0,
            parent_pk1   => 0,
            identity_pk1 => $system_ident->id,
            body         => '',
        });

        unless ( $data_import and ref $data_import eq 'HASH' ) {
            $self->storage->dbh->do($key_check_on) if $key_check_on;
            return;
        }

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

sub default_comment {
    my ( $self ) = @_;

    $self->resultset('Comment')->search(
        { parent_pk1 => 0, identity_pk1 => $self->system_identity->id }
    )->first;
}

sub default_comment_type {
    my ( $self ) = @_;

    $self->resultset('Comment::Type')->find_or_create(
        { name => '@comment' }
    );
}

sub system_identity {
    my ( $self ) = @_;

    $self->resultset('Person::Identity')->search(
        { realm => 'system', ident => 'system' },
        {
            prefetch => [ 'person' ]
        }
    )->first;
}

sub get_status {
    my ( $self, $id ) = @_;

    $self->resultset('Ticket::Status')->find_or_create({ name => $id });
}

sub get_role {
    my ( $self, $id ) = @_;

    $self->resultset('Role')->find_or_create({ name => $id });
}

sub tokenize {
    my ( $self, $field ) = @_;
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
