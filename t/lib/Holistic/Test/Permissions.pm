package Holistic::Test::Permissions;

use Moose::Role;
use Test::More;
use MooseX::MethodAttributes::Role;
use Try::Tiny;

with 'Holistic::Test::Schema',
     'Holistic::Test::Person';

=head1 Permission Tests

=head2 CREATES

This test creates several groups, people, queues and tickets.

=head2 Permission Flow

Things that have permissions:

=over

=item Group->permissions

=item Queue->permissions

=item Ticket->permissions

=item Person->permissions

=back

Each permission can be negated.

=cut

sub shut_up_permissions : Plan(17) {
    my ( $self, $data ) = @_;

    # We create people and groups
    die "Need person/group tests to run"
        unless $self->meta->does_role('Holistic::Test::Person');
    die "Need queue tests to run"
        unless $self->meta->does_role('Holistic::Test::Queue');

    my $role = $self->schema->get_role( $data->{role} || 'Test Role' );
    my $ident = $self->run_test('person_create', {
        name  => 'User 1',
        token => 'user_1',
        email => 'user_1@coldhardcode.com',
        ident => 'user_1'
    });
    my $person = $ident->person;

    my $anon_group = $self->run_test('group_create',
        {
            name  => 'anonymous',
            token => 'anonymous',
            email => 'anonymous@holistic.coldhardcode.com' 
        });
    ok($anon_group, 'created anonymous group');

    my $all_group = $self->run_test('group_create',
        {
            name  => 'Registered Users',
            token => 'all_users',
            email => 'all@holistic.coldhardcode.com' 
        });
    ok($all_group, 'created global group');
    $all_group->add_to_persons($person, { role => $role });

    my $admin_group = $self->run_test('group_create',
        {
            name  => 'Admin Users',
            token => 'admin_users',
            email => 'admin@holistic.coldhardcode.com' 
        });
    ok($admin_group, 'created admin group');
    $admin_group->add_to_persons($person, { role => $role });
    my $mgr_group = $self->run_test('group_create',
        {
            name  => 'Managers',
            token => 'managers',
            email => 'managers@holistic.coldhardcode.com' 
        });
    ok($mgr_group, 'created global group');
    my $devel_group = $self->run_test('group_create',
        {
            name  => 'Developers',
            token => 'developers',
            email => 'developers@holistic.coldhardcode.com' 
        });
    ok($devel_group, 'created devel group');

    my $triage = $self->run_test('queue_create',
        {
            name  => 'Triage Queue',
            token => 'triage',
        });
    ok($triage, 'created triage queue');

    my $queue = $self->run_test('queue_create',
        {
            name  => 'Ticket Queue',
            token => 'tickets',
        });
    ok($queue, 'created tickets queue');

    # Product specific

    my $product = $self->schema->resultset('Product')->create({ name => "Test Product" });
    my $product2 = $self->schema->resultset('Product')->create({ name => "Test Product2" });
    $triage->product_links->create({ product_pk1 => $product->id });
    $queue->product_links->create({ product_pk1 => $product->id });


    my $pset = $anon_group->permission_set;
    foreach my $perm ( qw/TICKET_VIEW FILE_VIEW LOG_VIEW MILESTONE_VIEW REPORT_VIEW ROADMAP_VIEW/ ) {
        my $p = $self->resultset('Permission')->find_or_create({ name => $perm });
        $pset->add_to_permissions( $p );
    }
    # XX this is a total bullshit test.
    is_deeply(
        [ sort keys %{ $anon_group->inflate_permissions } ],
        [ sort qw/TICKET_VIEW FILE_VIEW LOG_VIEW MILESTONE_VIEW REPORT_VIEW ROADMAP_VIEW/ ],
        'inflation test'
    );
}

1;
