package Holistic::Test::Schema;

use Moose::Role;
use MooseX::MethodAttributes::Role;

use Carp;
use Try::Tiny;
use Test::More;

use DBI;

with 'Holistic::Role::Schema';

sub deploy : Plan(2) {
    my ( $self ) = @_;

    {
        # Unlink if we're under sqlite
        my @parts = DBI->parse_dsn( $self->connect_info->[0] );
        if ( $parts[1] =~ /sqlite/i ) {
            if ( -f $parts[4] ) {
                unlink($parts[4])
                    or carp "Couldn't unlink $parts[4], deploy may fail";
            }
        }
    }

    my $err = undef;
    try { $self->schema->deploy; }
    catch { $err = $_; carp $_; };
    ok(!$err, 'deploy');
    ok($self->schema->storage->connected, 'connected schema');
}

sub bootstrap : Test {
    my ( $self ) = @_;
    $self->schema->txn_do( sub {
        foreach my $type ( '@release' ) {
            $self->schema->resultset('Queue::Type')->create({ name => $type});
        }
        foreach my $type ( '@feature', '@defect', '@support' ) {
            $self->schema->resultset('Ticket::Type')->create({ name => $type });
        }
        foreach my $type ( '@low', '@medium', '@high' ) {
            $self->schema->resultset('Ticket::Priority')->create({ name => $type });
        }

        ok(1, 'bootstrapped dataset is done');
    });
}

no Moose::Role;

1;
