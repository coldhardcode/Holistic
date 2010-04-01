#!/usr/bin/perl
use strict;

use Data::Dumper;
use DateTime;
use Holistic::Schema;
use YAML qw(LoadFile);

use Holistic::Conversion::Trac;

my $conv = Holistic::Conversion::Trac->new_with_options;

my $conf = LoadFile($conv->config);
# die Dumper($conf->{'Model::Schema'}->{connect_info});

my $schema = Holistic::Schema->connect(@{ $conf->{'Model::Schema'}->{connect_info} });

my $dbh = DBI->connect(
    'DBI:mysql:database='.$conv->database.';host='.$conv->host.';port='.$conv->port,
    $conv->username, $conv->password
);

my $ticket_rs = $schema->resultset('Ticket');

# XX Need some type map for our types
my %ticket_type_cache;
my $ticket_type_rs = $schema->resultset('Ticket::Type');

my %person_cache;
my $person_rs = $schema->resultset('Person');

my %identity_cache;
my $identity_rs = $schema->resultset('Person::Identity');

my $tick_sth = $dbh->prepare('SELECT id, type, time, changetime, component, severity, priority, owner, reporter, cc, version, milestone, status, resolution, summary, description, keywords FROM ticket');

$tick_sth->execute;

my %row;
$tick_sth->bind_columns( \( @row{ @{$tick_sth->{NAME_lc} } } ));
while ($tick_sth->fetch) {
    make_ticket(\%row);
    die;
}

sub make_ticket {
    my ($row) = @_;

    # Find a type
    my $type = $ticket_type_cache{$row->{type}};
    unless(defined($type)) {
        $type = $ticket_type_rs->create({
            name => $row->{type}
        });
        $ticket_type_cache{$row->{type}} = $type
    }

    my ($rep_person, $rep_ident) = find_person_and_identity($row->{reporter});

    my $tick = $ticket_rs->create({
        type_pk1    => $type->id,
        identity_pk1=> $rep_ident->id,
        name        => $row->{summary},
        description => $row->{description},
        dt_created=> DateTime->from_epoch(epoch => $row->{time}),
        dt_updated=> DateTime->from_epoch(epoch => $row->{changetime})
    });
}

sub find_person_and_identity {
    my ($email) = @_;

    # Find a person
    my $person = $person_cache{$email};
    unless(defined($person)) {
        $person = $person_rs->create({
            token   => 'wtf?',
            name    => $email,
            public  => 1,
            email   => $email,
            timezone => 'America/Chicago', # XX
        });
    }

    # Find an identity
    my $identity = $person->identities->first if($person->identities->count);
    unless(defined($identity)) {
        $identity = $person->add_to_identities({
            realm   => 'wtf?', # XX
            ident   => 'wtf?', # XX
            secret  => 'wtf?', # XX
            active  => 1
        });
    }

    return ( $person, $identity );
}