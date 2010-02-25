package Holistic::Role::Permissions;

use Moose::Role;

requires 'table', 'permission_hierarchy', 'is_member';

sub permission_set_result_source { 'Permission::Set' }

after 'table' => sub {
    my ( $class ) = @_;

    $class->add_columns(
        permission_set_pk1 => {
            data_type      => 'INTEGER',
            is_nullable    => 1,
            size           => undef,
            is_foreign_key => 1
        },
    );

    $class->belongs_to(
        'discussable'   => $class->permission_set_result_source,
        { 'foreign.pk1' => 'self.permission_set_pk1' },
    );
};

before 'insert' => sub {
    my ( $self ) = @_;
    unless ( defined $self->permission_set_pk1 ) {
        my $set = $self->result_source->schema
            ->resultset( "Permission::Set" )
            ->find_or_create({ result_class => $self->result_class });

        $self->permission_set_pk1( $set->id );
    }
};

# Returns a result source of all permissions applicable to this object.
sub permissions {
    my ( $self ) = @_;
}

sub check_access {

}

sub for {
    my ( $scope, $object ) = @_;
}


no Moose::Role;
1;
