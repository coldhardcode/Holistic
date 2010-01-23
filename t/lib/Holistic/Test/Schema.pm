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

    my $system_person = $self->resultset('Person')->create({
        name  => 'Holistic System User',
        token => 'holistic',
        email => 'foo@bar.com',
    });
    $system_person->add_to_identities({
        realm  => 'system',
        id     => 'system',
        active => 0
    });
}

no Moose::Role;

1;
