package Holistic::Role::ACL;

use Moose::Role;

requires 'action_list', 'is_member';

sub check_access {
    my ( $self, $person, $action ) = @_;

    my $roles = undef;

    if ( defined $action ) {
        my $in_roles = $self->action_list->{$action};
        Carp::croak 
            "Invalid action ($action) for permission check on " . ( ref $self )
            unless defined $in_roles;
        my $roles = $self->result_source->schema->resultset('Role')
            ->search({ name => $in_roles });
    }
    return $self->is_member($person, $roles);

    if ( $action eq 'comment' ) {
        return $self->is_member($person);
    }
    elsif ( $action =~ /(add|remove)_person/ ) {
        my $role = $self->schema->resultset('Role')
            ->find_or_create({ name => 'Member' });
        return $self->is_member($person, $role);
    }
    # False?
    return 1 == 0;
}

1;
