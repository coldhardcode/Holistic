package Holistic::Controller::Admin::Group;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'group' } },
    class      => 'Schema::Group',
    rs_key     => 'group_rs',
    object_key => 'group',
    prefetch   => [ 'person_links' ],
    scope      => 'group',
    create_string => 'The group has been created.',
    update_string => 'The group has been updated.',
    error_string  => 'There was an error processing your request, please try again.',

);

sub management : Chained('setup') Args(0) ActionClass('REST') { }

sub management_GET {
    my ( $self, $c ) = @_;
 
    $c->stash->{person_groups} = $self->_groups( $c );
    $self->status_ok(
        $c,
        entity => {
            groups => [ $c->stash->{person_groups} ]
        }
    );
}

sub _groups {
    my ( $self, $c ) = @_;

    my $rs = $c->stash->{$self->rs_key}->search;
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my $groups = {};
    foreach my $row ( $rs->all ) {
        my $links = delete $row->{person_links};
        foreach my $link ( @$links ) {
            $groups->{$link->{person_pk1}} ||= [];
            push @{ $groups->{$link->{person_pk1}} }, {
                group_pk1 => $row->{pk1},
                name      => $row->{name},
                role_pk1  => $link->{role_pk1},
            };
        }
    }

    return $groups;
}

sub management_POST {
    my ( $self, $c, $data ) = @_;
    $data ||= $c->req->data || $c->req->params;
    $c->log->_dump($data);
    my $role = $c->model('Schema')->schema->get_role('Member');

    # Which perspective are we updated?
    if ( $data->{groups} ) {
        # Passed in groups
    }
    elsif ( $data->{persons} ) {
        # Passed in:
        # persons => {
        #   $person_pk1 => [ 
        #       { group_pk1: $group_pk1, role_pk1: $role_pk1 },
        #       { group_pk1: $group_pk2, role_pk1: $role_pk1 }
        #   ],
        # }
        unless ( ref $data->{persons} eq 'HASH' ) {
            # Bad API Call Error
            die "Asshole";
        }
        my $person_rs = $c->model('Schema::Person')
            ->search({ pk1 => [ keys %{ $data->{persons} } ]});
        foreach my $person ( $person_rs->all ) {
            my $groups = $data->{persons}->{$person->id};
            next unless defined $groups;
            unless ( ref $groups eq 'ARRAY' ) {
                die "Asshole";
            }
            my @group_pk1s = ();
            foreach my $g ( @$groups ) {
                push @group_pk1s, $g->{group_pk1};
                # We don't support roles yet
                #$group->{role_pk1};
            }
            $person->group_links->delete;
            
            my @groups = $c->model('Schema::Group')->search({ pk1 => \@group_pk1s })->all;
            foreach my $group ( @groups ) {
                $person->add_to_groups( $group, { role_pk1 => $role->id } );
            }
        }
    }
    elsif ( $data->{person_pk1} ) {
        my @p_pk1s = ref $data->{person_pk1} ?
            @{ $data->{person_pk1} } : ( $data->{person_pk1} );

        my @g_pk1s = ref $data->{group_pk1} ?
            @{ $data->{group_pk1} } : ( $data->{group_pk1} );

        my @groups = $c->model('Schema::Group')->search({ pk1 => \@g_pk1s })->all;

        foreach my $pk1 ( @p_pk1s ) {
            my $person = $c->model('Schema::Person')->find($pk1);
            if ( not defined $person ) {
                $c->log->error("$pk1 is not a valid person id");
                next;
            }
            $person->group_links->delete;
            foreach my $group ( @groups ) {
                $group->add_to_persons( $person, { role_pk1 => $role->id });
            }
        }
    }

    # XX if browser, we're all browsers now.
    if ( $c->req->content_type eq 'application/x-www-form-urlencoded' ) {
        $c->res->redirect( $c->req->uri );
        $c->detach;
    }

    $self->status_ok(
        $c,
        entity => {
            groups => $self->_groups( $c )
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
