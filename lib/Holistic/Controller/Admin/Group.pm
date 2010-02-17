package Holistic::Controller::Admin::Group;

use Moose;

BEGIN { extends 'Holistic::Base::Controller::REST'; }

__PACKAGE__->config(
    actions    => { 'setup' => { PathPart => 'group' } },
    class      => 'Schema::Group',
    rs_key     => 'group_rs',
    object_key => 'group',
    prefetch   => [ 'person_links' ]
);

sub management : Chained('setup') Args(0) ActionClass('REST') { }

sub management_GET { 
    my ( $self, $c ) = @_;
    my $rs = $c->model('Schema::Group')->search(
        {
                #'me.active' => 1, # TODO
        },
        {
            prefetch => [ 'person_links' ]
        }
    );
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    $c->stash->{person_groups} = {};
    foreach my $row ( $rs->all ) {
        my $links = delete $row->{person_links};
        foreach my $link ( @$links ) {
            $c->stash->{person_groups}->{$link->{person_pk1}} ||= [];
            push @{ $c->stash->{person_groups}->{$link->{person_pk1}} }, {
                group_pk1 => $row->{pk1},
                name      => $row->{name},
                role_pk1  => $link->{role_pk1},
            };
        }
    }

    $self->status_ok(
        $c,
        entity => {
            groups => [ $rs->all ]
        }
    );
}

sub management_POST {
    my ( $self, $c, $data ) = @_;
    $data ||= $c->req->data || $c->req->params;

    my @p_pk1s = ref $data->{person_pk1} ?
        @{ $data->{person_pk1} } : ( $data->{person_pk1} );

    my @g_pk1s = ref $data->{group_pk1} ?
        @{ $data->{group_pk1} } : ( $data->{group_pk1} );

    my $role = $c->model('Schema')->schema->get_role('Member');

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

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
