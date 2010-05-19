#!/usr/bin/perl
use strict;

use Data::Dumper;
use DateTime;
use Holistic::Schema;
use List::MoreUtils qw(uniq);
use Text::Trac;
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

my $trac_parser = Text::Trac->new(
    trac_ticket_url => '/ticket/id/'
);

my $ticket_rs = $schema->resultset('Ticket');

# XX Need some type map for our types
my %ticket_type_cache;
my $ticket_type_rs = $schema->resultset('Ticket::Type');

my %person_cache;
my $person_rs = $schema->resultset('Person');

my %identity_cache;
my $identity_rs = $schema->resultset('Person::Identity');

my %queue_cache;
my $queue_rs = $schema->resultset('Queue');
# System queue?
my $default_queue = 1; # XX Arbitrary, but everything has to have a queue

my %product_cache;
my $product_rs = $schema->resultset('Product');

my %status_cache;
my $status_rs = $schema->resultset('Ticket::Status');

my %priority_cache;
my $priority_rs = $schema->resultset('Ticket::Priority');

my %tag_cache;
my $tag_rs = $schema->resultset('Tag');

my $tick_sth = $dbh->prepare('SELECT id, type, time, changetime, component, severity, priority, owner, reporter, cc, version, milestone, status, resolution, summary, description, keywords FROM ticket');
my $mile_sth = $dbh->prepare('SELECT name, due, completed, description FROM milestone WHERE name=?');
my $prod_sth = $dbh->prepare('SELECT name, owner, description FROM component WHERE name=?');
my $change_sth = $dbh->prepare("SELECT author, field, time, newvalue FROM ticket_change WHERE ticket=? ORDER BY TIME ASC");

my $status_change_sth = $dbh->prepare("SELECT oldvalue,newvalue FROM ticket_change WHERE ticket=? AND field = 'status' ORDER BY TIME ASC");

my $worklog_type = $schema->resultset('Comment::Type')->find_or_create({ name => '@worklog' });

#$tick_sth->execute('5.0.0');
$tick_sth->execute();

my %row;
$tick_sth->bind_columns( \( @row{ @{$tick_sth->{NAME_lc} } } ));
while ($tick_sth->fetch) {
    make_ticket(\%row);
    # die;
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
    my $product = find_product($row->{$conv->product});
    my $queue   = find_queue($row->{$conv->queue}, $product, $row->{id});
    my $status  = find_status($queue, $row->{status} );

    my $desc = $trac_parser->parse($row->{description});
    my $tick = $ticket_rs->create({
        pk1             => $row->{id},
        type_pk1        => $type->id,
        identity_pk1    => $rep_ident->id,
        priority_pk1    => find_priority($row->{$conv->priority})->id,
        name            => $row->{summary},
        description     => $desc,
        queue_pk1       => $status->id,
        dt_created      => DateTime->from_epoch(epoch => $row->{time}),
        dt_updated      => DateTime->from_epoch(epoch => $row->{changetime})
    });

    ############## TICKET CHANGES
    $change_sth->execute($row->{id});
    my %change_row;
    $change_sth->bind_columns( \( @change_row{ @{$change_sth->{NAME_lc} } } ));
    while ($change_sth->fetch) {
        # Use the system user if there's no author
        # XX this only works if you use emails, should probably use token or whatever
        $change_row{author} = 'no-reply@coldhardcode.com' unless(defined($change_row{author}) && $change_row{author} ne '');
        my ($change_person, $change_ident) = find_person_and_identity($change_row{author});

        $tick->add_to_changes({
            identity_pk1 => $change_ident->id,
            name         => $change_row{field},
            value        => $change_row{newvalue} || '',
            changeset    => $change_row{time}
        }) unless $change_row{field} eq 'comment'; # Comments aren't changes

        # Comments
        if($change_row{field} eq 'comment') {
            # No reason to have empty ones
            next unless defined($change_row{newvalue}) && $change_row{newvalue} ne '';

            my $html = $trac_parser->parse($change_row{newvalue});
            next if !defined($html) || ($html eq '');
            my $is_worklog = 0;
            if ( $html =~ /changeset/ ) {
                $is_worklog = 1;
            }
            $tick->add_comment({
                identity => $change_ident,
                body => $html,
                dt_created => DateTime->from_epoch(epoch => $change_row{time}),
                ( $is_worklog ? ( type_pk1 => $worklog_type->id ) : () )
            });
        # State (resolution in Trac) changes
        } elsif($change_row{field} eq 'resolution') {
            # Here we find the appropriate closed state
#warn "Finding closed state off " . $tick->queue . "\n";
            my $closed_status = find_status($tick->queue->top_parent, 'closed');
#warn "Finding closed state: " . $closed_status->path . "\n";
            my $status = find_status($closed_status, $change_row{newvalue} || 'closed' );
            $tick->update({ queue_pk1 => $status->id });

            # XX Need to update the changelog:
            #    identity_pk1 => $change_ident->id,
            #    status_pk1 => $status->id,
            #    dt_created => DateTime->from_epoch(epoch => $change_row{time})
        }
    }

    ################ TICKET TAGS
    if($conv->tags) {
        if(defined($row->{keywords}) && ($row->{keywords} ne '')) {
            my @keywords = split(/ /, $row->{keywords});
            @keywords = uniq(@keywords);
            foreach my $keyword (@keywords) {
                $keyword =~ s/,//;
                $keyword = lc($keyword);
                my $tag = find_tag($keyword);
                $tick->add_to_ticket_tags({
                    tag_pk1 => $tag->id
                });
            }
        }
    }
}

sub find_tag {
    my ($name) = @_;

    my $tag = $tag_cache{$name};

    unless(defined($tag)) {
        $tag = $tag_rs->create({
            name => $name
        });
        $tag_cache{$name} = $tag;
    }
    return $tag;
}

sub find_person_and_identity {
    my ($email) = @_;

    # Find a person
    my $person = $person_cache{$email};

    unless(defined($person)) {
        $person = $person_rs->create({
            token   => $email,
            name    => $email,
            public  => 1,
            email   => $email,
            timezone => 'America/Chicago', # XX
        });
        $person_cache{$email} = $person;
    }

    # Find an identity
    my $identity = $person->local_identity;

    unless(defined($identity)) {
        $identity = $person->add_to_identities({
            realm   => 'local',
            ident   => $email,
            secret  => '', # XX, need a password?
            active  => 1
        });
        $identity_cache{$email} = $identity;
    }

    return ( $person, $identity );
}

sub find_product {
    my ($name) = @_;

    my $product = $product_cache{$name};
    unless(defined($product)) {

        $prod_sth->execute($name);
        my %row;
        $prod_sth->bind_columns( \( @row{ @{$prod_sth->{NAME_lc} } } ));

        # XX Need due date and completed!
        $product = $product_rs->create({
            name        => $name,
            description => $row{description}
        });
        $product_cache{$name} = $product;
    }
    return $product;
}

sub find_queue {
    my ($name, $product, $ticket_id) = @_;

    my $queue = $queue_cache{$name};
    unless(defined($queue)) {

        $mile_sth->execute($name);
        my %row;
        $mile_sth->bind_columns( \( @row{ @{$mile_sth->{NAME_lc} } } ));

        my $token = $schema->tokenize($name);
        # XX Need due date and completed!
        $queue = $queue_rs->create({
            name        => $name,
            token       => $token,
            path        => $token,
            description => $row{description},
            traversal_type => 2
        });
        if(defined($product)) {
            $product->add_to_queue_links({ queue_pk1 => $queue->id });
        }

        $queue_cache{$name} = $queue;
    }
    if ( $ticket_id ) {
        $status_change_sth->execute($ticket_id);
        my %change_row;
        $status_change_sth->bind_columns( \( @change_row{ @{$status_change_sth->{NAME_lc} } } ));
        while ($status_change_sth->fetch) {
            #warn " Status change: $change_row{oldvalue} => $change_row{newvalue}\n";
            if ( not $status_cache{join(":", $queue->id, $change_row{oldvalue})} ) {
                my $status = $queue->add_step({ name => $change_row{oldvalue} });
                $status_cache{join(":", $queue->id, $status->name)} = $status;
            }

            if ( not $status_cache{join(":", $queue->id, $change_row{newvalue})} ) {
                my $status = $queue->add_step({ name => $change_row{newvalue} });
                $status_cache{join(":", $queue->id, $status->name)} = $status;
            }
        }
    }
    return $queue;
}

sub find_status {
    my ($milestone, $name) = @_;
    my $status_name = join(":", $milestone->id, $name);
    my $status = $status_cache{$status_name};

    unless(defined($status)) {
        $status = $milestone->add_step({
            name        => $name,
            description => ''
        });
        $status_cache{$status_name} = $status;
    }
    return $status;
}

sub find_priority {
    my ($name) = @_;

    my $pri = $priority_cache{$name};
    unless(defined($pri)) {
        $pri = $priority_rs->create({
            name => $name,
        });
        $priority_cache{$name} = $pri;
    }
    return $pri;
}
