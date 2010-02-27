package Holistic::Role::Permissions;

use Moose::Role;

requires 'table', 'permission_hierarchy';

use Holistic::Permissions;

has 'permission_set_result_source' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Permission::Set::Object'
);

has '_permissions' => (
    isa => 'Holistic::Permissions',
    lazy_build => 1
);

sub permissions {
    my ( $self ) = @_;
    my $attr = shift->meta->get_attribute('_permissions');

    $attr->get_value( $self );
}

after 'table' => sub {
    my ( $class ) = @_;

    my $source = $class->result_source_instance;

    $class->add_columns(
        result_class => {
            data_type      => 'VARCHAR',
            is_nullable    => 0,
            size           => 255,
            default_value  => $source->name
        },
    );
    $class->has_many(
        'permission_set_objects' => 'Holistic::Schema::Permission::Set::Object',
        {
            'foreign.foreign_pk1'  => 'self.pk1',
            'foreign.result_class' => 'self.result_class'
        },
    );
    $class->many_to_many('permission_sets' => 'permission_set_objects' => 'permission_set' );

    # This would be awesome:
    if ( 0 ) {
        $class->schema->resultset($class->permission_set_result_source)
            ->result_source->belongs_to(
                $class->name => $class,
                {
                    'foreign.pk1'           => 'self.foreign_pk1',
                    'foreign.result_class'  => 'self.result_class'
                }
            );
    }
};

sub _build__permissions {
    my ( $self ) = @_;
    Holistic::Permissions->new(
        scope => $self,
    );
}


sub add_permission {
    my ( $self, $permission ) = @_;

    $self->permission_set->permission_links->create({ permission => $permission });
}

sub check_permission {
    my ( $self, $person, $permission ) = @_;

    my $perm = $self->fetch_permissions_by_person($person);

    return exists $perm->{$permission};
}

sub fetch_permissions {
    my ( $self, $by, $object ) = @_;

    if ( $by eq 'person' ) {
        $self->fetch_permissions_by_person( $object );
    }
    elsif ( $by eq 'group' ) {
        $self->fetch_permissions_by_person( $object );
    }
}

sub fetch_permissions_by_group {

}

sub fetch_permissions_by_person {
    my ( $self, $person ) = @_;
    # This object's permissions do not condescend, simply skip.
    my $desc = $self->permission_hierarchy->{condescends};

    return undef unless defined $desc;

    my $find_myself = {
        map { my $n = $_; "me.$n" => $self->$n; } $self->result_source->primary_columns 
    };

    if ( defined $person ) {
        $find_myself->{'group.pk1'} = { '-in' => [ $person->group_links->get_column('group_pk1')->all ] };
    }

    my $rs = $self->result_source->resultset->search(
        $find_myself,
        { prefetch => $desc }
    );
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    return $self->_permissions_from_rs( $rs );
}

sub _permissions_from_rs {
    my ( $self, $rs ) = @_;

    use Data::Dumper;
    use Data::Visitor::Callback;

    my @sets = ();
    my $v = Data::Visitor::Callback->new(
        hash => sub {
            my $val = $_;
            if ( exists $val->{permission_set} ) {
                push @sets, $val->{permission_set}->{pk1};
            }
            $val;
        },
    );
    
    $v->visit([ $rs->all ]);

    my $set_rs = $self->schema->resultset('Permission::Set')->search(
        { 'me.pk1' => [ @sets ] },
        { prefetch => { 'permission_links' => 'permission' } }
    );

    # Needs to be in order of the values above
    my %matches = ();
    while ( my $set = $set_rs->next ) {
        my $perms = $set->permissions;
        while ( my $perm = $perms->next ) {
            $matches{$set->id} ||= [];
            push @{$matches{$set->id}}, { $perm->get_columns };
        }
    }

    my %final = ();
    # Guarantee order
    foreach my $set ( @sets ) {
        next unless defined $matches{$set};
        foreach my $perm ( @{ $matches{$set} } ) {
            if ( $perm->{prohibit} ) {
                delete $final{$perm->{name}};
            } else {
                $final{$perm->{name}} = $perm;
            }
        }
    }

    return \%final;
}

no Moose::Role;
1;
