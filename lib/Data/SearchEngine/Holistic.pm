package Data::SearchEngine::Holistic;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Holistic::Results;
use Hash::Merge qw(merge);
use Search::QueryParser;
use DBIx::Class::ResultSet::Faceter;

has fields => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        {
            name => {
                alias => 'me',
                type => 'text',
                field => 'name'
            },
            date_on => {
                alias => 'me',
                field => 'dt_created',
                type => 'date'
            },
            description => {
                alias => 'me',
                type => 'text',
                field => 'description',
            },
            owner => {
                alias => 'person',
                type => 'text',
                field => 'token'
            },
            priority => {
                alias => 'priority',
                type => 'text',
                field => 'name'
            },
            queue => {
                alias => 'me',
                type => 'num',
                field => 'queue_pk1'
            },
			queue_name => {
				alias => 'queue',
                type => 'text',
				field => 'path'
			},
            reporter => {
                alias => 'me',
                type => 'text',
                field => 'identity_pk1'
            },
            reporter_email => {
                alias => 'person',
                type => 'text',
                field => 'email'
            },
            reporter_name => {
                alias => 'person',
                type => 'text',
                field => 'name'
            },
            role => {
                alias => 'role',
                type => 'text',
                field => 'name'
            },
            status => {
                alias => 'queue',
                type => 'text',
                field => 'name'
            },
            type => {
                alias => 'type',
                type => 'text',
                field => 'name'
            }
        }
    },
    lazy => 1
);

has query_parser => (
    is => 'ro',
    lazy_build => 1
);

has schema => (
    is => 'ro',
    required => 1
);

sub _build_query_parser {
    my ($self) = @_;

    return Search::QueryParser->new;
}

sub search {
    my ($self, $oquery) = @_;

    my $start = time;

    my @items = ();
    my $full_rs = $self->create_resultset($oquery);

    $full_rs = $self->_add_filters($full_rs, $oquery);

    my $tickets = $full_rs->search(undef, {
        page => $oquery->page, rows => $oquery->count,
    });

    my $pager = Data::SearchEngine::Paginator->new(
        current_page => $oquery->page,
        entries_per_page => $oquery->count,
        total_entries => $full_rs->count
    );

    my $faceter = DBIx::Class::ResultSet::Faceter->new;
    $faceter->add_facet('Column', { name => 'date_on', column => 'dt_created.ymd' });
    $faceter->add_facet('Column', { name => 'status', column => 'status.name' });
    $faceter->add_facet('Column', { name => 'priority', column => 'priority.name' });
    $faceter->add_facet('Column', { name => 'type', column => 'type.name' });
    $faceter->add_facet('Column', { name => 'owner', column => 'owner.token' });
    # Doesn't work because there can be > 1 product
    # $faceter->add_facet('Column', { name => 'product', column => 'queue.products.first' });

    my $fac_res = $faceter->facet($full_rs);

    while(my $tick = $tickets->next) {
        push(@items, Data::SearchEngine::Holistic::Item->new(
            id => $tick->id,
            ticket => $tick,
            score => 1
        ));
    }

    my $results = Data::SearchEngine::Holistic::Results->new(
        query => $oquery,
        pager => $pager,
        items => \@items,
        elapsed => time - $start,
        facets => $fac_res->facets
    );
}

sub create_resultset {
    my ($self, $oquery) = @_;

    my $q = $self->query_parser->parse($oquery->query);
    my %conds = ();

    my %attrs = (
        join => [
            'type', 'priority', 'queue',
            {
                'ticket_persons' => [ 'person', 'role' ],
                'ticket_tags'    => 'tag'
            },
        ],
        prefetch => [ 'type', 'priority', 'queue', 'status' ],
		group_by => 'me.pk1'
    );

    # Create a list of ANDs that we can fiddle with later
    my @ands = ();

    if(exists($q->{''}) && scalar(@{ $q->{''} })) {
        my $reqs = [];
        $self->add_conditions($q->{''}, $reqs, 0, $oquery);
        $conds{'-and'} = $reqs;
    }
    if(exists($q->{'+'}) && scalar(@{ $q->{'+'} })) {
        my $reqs = [];
        $self->add_conditions($q->{'+'}, $reqs);
        $conds{'-and'} = $reqs;
    }
    if(exists($q->{'-'}) && scalar(@{ $q->{'-'} })) {
        $self->add_conditions($q->{'-'}, \@ands, 1);
    }

    # Merge all the hashes in the AND section so we can query
    foreach my $a (@ands) {
        %conds = %{ merge(\%conds, $a) };
    }

    return $self->schema->resultset('Ticket')->search(\%conds, \%attrs);
}

# This method expects to get the sub-set of query to iterate over and an
# array-ref in which to push conditions.  It is up to the caller to manage
# which sub-set and array-ref is passed.
sub add_conditions {
    my ($self, $query, $conditions, $negate, $oquery) = @_;

    my $fields = $self->fields;

    foreach my $i (@{ $query }) {
        my $field   = $i->{field};

        # If the field isn't defined in our list, bail
        next unless defined($fields->{$field}) || $field eq '';

        my $op      = $i->{op};
        my $val     = $i->{value};

        # An empty field defaults to using a LIKE on the name & description,
        # op is irrelevant cuz you can't put an op on nothing
        if($field eq '') {
            if($negate) {
                push(@{ $conditions }, {
                    '-and' => [
                        'me.name' => { -not_like => "\%$val\%" },
                        'me.description' => { -not_like => "\%$val\%" },
                    ]
                });
            } else {
                push(@{ $conditions }, {
                    '-or' => [
                        'me.name' => { -like => "\%$val\%" },
                        'me.description' => { -like => "\%$val\%" },
                    ]
                });
            }
        } else {
            my $fdef = $fields->{$field};
            if($op eq ':' && $fdef->{type} ne 'text') {
                # :s are basically LIKEs.  If we are not dealing with a text
                # field then convert the op to a =
                $op = '=';
            }

            # If we got here, there must be a field

            # We can only do likes if it's text, but it's been handled for us
            # above...
            if($op eq ':') {
                if($negate) {
                    push(@{ $conditions }, {
                        $fdef->{alias}.'.'.$fdef->{field} => { -not_like => "\%$val\%" }
                    });
                } else {
                    push(@{ $conditions }, {
                        $fdef->{alias}.'.'.$fdef->{field} => { -like => "\%$val\%" }
                    });
                }
            } elsif($op eq '=') {
                push(@{ $conditions }, {
                    $fdef->{alias}.'.'.$fdef->{field} => $val
                });
            # Can't be text for > and <
            } elsif(($op eq '>') && $fdef->{type} ne 'text') {
                push(@{ $conditions }, {
                    $fdef->{alias}.'.'.$fdef->{field} => { '>' =>  $val }
                });
            } elsif(($op eq '<') && $fdef->{type} ne 'text') {
                push(@{ $conditions }, {
                    $fdef->{alias}.'.'.$fdef->{field} => { '<' =>  $val }
                });
            }
        }
    }
}

sub _add_filters {
    my ($self, $rs, $oquery) = @_;

    return $rs unless $oquery->has_filters;

    foreach my $filter ($oquery->filter_names) {

        my $fdef = $self->fields->{$filter};

        next unless defined($fdef);

        if($fdef->{type} eq 'date') {
            my $dt = $oquery->get_filter($filter);
            $rs = $rs->search({
                $fdef->{alias}.'.'.$fdef->{field} => { -between => [ "$dt 00:00:00", "$dt 23:59:59" ] }
            });
        } else {
            $rs = $rs->search({
                $fdef->{alias}.'.'.$fdef->{field} => $oquery->get_filter($filter)
            });
        }
    }

    return $rs;
}

__PACKAGE__->meta->make_immutable;

1;
