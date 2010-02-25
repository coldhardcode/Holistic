package Holistic::Role::Permissions;

use Moose::Role;

requires 'table', 'permission_hierarchy';

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
        'permission_set'   => $class->permission_set_result_source,
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

    $self->permission_set->permissions;
}

sub add_permission {
    my ( $self, $permission ) = @_;

    $self->permission_set->permission_links->create({ permission => $permission });
}

sub check_permission {
    my ( $self, $user, $permission ) = @_;
}

sub for {
    my ( $scope, $object ) = @_;
}


sub is_member {
    my ( $self, $person ) = @_;

    my $ret;
    
    if ( $self->can('groups') ) {
        $ret = $self->groups(
            { 'person.pk1' => $person->id },
            { prefetch => [ 'person' ] }
        )->first;
        return $ret if defined $ret;
    }
    my $desc = $self->permission_hierarchy->{condescends};
    return undef unless defined $desc;

    my @rels = ();

    if ( $desc eq 'ARRAY' ) {
        @rels = @$desc
    } else {
        @rels = keys %$desc;
    }

    my $next_rel = pop @rels;
    # Needs to traverse has_many
    my $info = $self->result_source->relationship_info( $next_rel );
    confess "No information specified on next relationship to follow ($next_rel, check permission_hierarchy"
        unless defined $info;
use Data::Dumper;
die Dumper($info);

    if ( $self->$desc->meta->does_role('Holistic::Role::Permissions') ) {
        return $self->$desc->is_member( $person );
    }
}

no Moose::Role;
1;
