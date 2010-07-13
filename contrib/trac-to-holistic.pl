#!/usr/bin/env perl

use strict;

use Data::Dumper;
use DateTime;
use Holistic::Schema;
use List::MoreUtils qw(uniq);
use Text::Trac;
use YAML qw(LoadFile);

use Holistic::Conversion::Trac;

my $conv = Holistic::Conversion::Trac->new_with_options;

$conv->import_users_and_groups;

my $ticket_rs = $conv->resultset('Ticket');

# XX Need some type map for our types
my %ticket_type_cache;
my $ticket_type_rs = $conv->resultset('Ticket::Type');

my %person_cache;
my $person_rs = $conv->resultset('Person');

my %identity_cache;
my $identity_rs = $conv->resultset('Person::Identity');

my %queue_cache;
my $queue_rs = $conv->resultset('Queue');
# System queue?
my $default_queue = 1; # XX Arbitrary, but everything has to have a queue

my %product_cache;
my $product_rs = $conv->resultset('Product');

my %status_cache;
my $status_rs = $conv->resultset('Status');

my %priority_cache;
my $priority_rs = $conv->resultset('Ticket::Priority');

my %tag_cache;
my $tag_rs = $conv->resultset('Tag');

my $mile_sth = $conv->prepare('SELECT name, due, completed, description FROM milestone WHERE name=?');
my $prod_sth = $conv->prepare('SELECT name, owner, description FROM component WHERE name=?');
my $change_sth = $conv->prepare("SELECT author, field, time, newvalue FROM ticket_change WHERE ticket=? ORDER BY TIME ASC");

my $status_change_sth = $conv->prepare("SELECT oldvalue,newvalue FROM ticket_change WHERE ticket=? AND field = 'status' ORDER BY TIME ASC");

my $worklog_type = $conv->resultset('Comment::Type')->find_or_create({ name => '@worklog' });

my $tick_sth;
if ( $conv->has_milestone ) {
    $tick_sth = $conv->prepare('SELECT id, type, time, changetime, component, severity, priority, owner, reporter, cc, version, milestone, status, resolution, summary, description, keywords FROM ticket WHERE milestone = ?');
    $tick_sth->execute($conv->milestone);
} else {
    $tick_sth = $conv->prepare('SELECT id, type, time, changetime, component, severity, priority, owner, reporter, cc, version, milestone, status, resolution, summary, description, keywords FROM ticket');
    $tick_sth->execute();
}

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

    my ($rep_person, $rep_ident) = $conv->find_person_and_identity($row->{reporter});
    my ($own_person, $own_ident) = $conv->find_person_and_identity($row->{owner});

    my $product = find_product($row->{$conv->product});
    my $queue   = find_queue($row->{$conv->queue}, $product, $row->{id});
    my $status  = find_status($queue, $row->{status} );

    my $desc = $conv->trac_parser->parse($row->{description});

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

    $tick->requestor($rep_person);
    $tick->owner($own_person);

    ############## TICKET CHANGES
    $change_sth->execute($row->{id});
    my %change_row;
    $change_sth->bind_columns( \( @change_row{ @{$change_sth->{NAME_lc} } } ));
    while ($change_sth->fetch) {
        # Use the system user if there's no author
        # XX this only works if you use emails, should probably use token or whatever
        $change_row{author} = 'no-reply@coldhardcode.com' unless(defined($change_row{author}) && $change_row{author} ne '');
        my ($change_person, $change_ident) = $conv->find_person_and_identity($change_row{author});
        $tick->add_to_changes({
            identity_pk1 => $change_ident->id,
            name         => $change_row{field},
            value        => $change_row{newvalue} || '',
            changeset    => $change_row{time},
            dt_created   => DateTime->from_epoch(epoch => $change_row{time}),
        }) unless $change_row{field} eq 'comment'; # Comments aren't changes

        # Comments
        if($change_row{field} eq 'comment') {
            # No reason to have empty ones
            next unless defined($change_row{newvalue}) && $change_row{newvalue} ne '';

            my $html = $conv->trac_parser->parse($change_row{newvalue});
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

        my $token = $conv->schema->tokenize($name);
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
    # We don't have reopened
    # XX we should do something more special in this case.  Like bake a cake.
    if ( $name eq 'reopened' ) {
        $name = 'assigned';
    }
    my $status_name = join(":", $milestone->id, $name);
    my $status = $status_cache{$status_name};

    unless(defined($status)) {
        $status = $milestone->add_step({
            name        => '@' . $name,
            description => ''
        });
        if ( $name =~ /closed/ ) {
            $milestone->update({ closed_queue_pk1 => $status->id });
            my $qs = $conv->resultset('Status')->find({ name => '@closed' });
            if ( not defined $qs ) {
                $qs = $conv->resultset('Status')->create({
                    name           => '@closed',
                    accept_tickets => 0,
                    accept_worklog => 0,
                });
            }
            $status->update({ status_pk1 => $qs->id });
        }
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
