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

sub _fetch_permissions_by_rel {
    my ( $self, $person, $rel ) = @_;

}

sub fetch_permissions {
    my ( $self, $person ) = @_;
    # This object's permissions do not condescend, simply skip.
    my $desc = $self->permission_hierarchy->{condescends};

    return undef unless defined $desc;

    my $find_myself = {
        map { my $n = $_; "me.$n" => $self->$n; } $self->result_source->primary_columns 
    };

    my $rs = $self->result_source->resultset->search(
        $find_myself,
        { prefetch => $desc }
    );
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

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
        my @perms = $set->permissions->get_column('name')->all;
        $matches{$set->id} = \@perms if @perms > 0;
    }

    my @final = ();
    foreach my $set ( @sets ) {
        next unless defined $matches{$set};
        push @final, @{ $matches{$set} };
        delete $matches{$set}; # delete after we're done, cheap uniq
    }

    print Dumper([ @final ]);
    return { map { $_ => $_ } @final };
}

no Moose::Role;
1;
