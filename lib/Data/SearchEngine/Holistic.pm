package Data::SearchEngine::Holistic;
use Moose;

use Time::HiRes qw(time);

with 'Data::SearchEngine';

use Data::SearchEngine::Holistic::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Holistic::Results;
use Hash::Merge qw(merge);
use Search::QueryParser;

has fields => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        {
            name => {
                alias => 'me',
                text => 1,
                field => 'name'
            },
            date_created => {
                alias => 'me',
                field => 'dt_created',
                text => 0
            },
            description => {
                alias => 'me',
                text => 1,
                field => 'description',
            },
            priority => {
                alias => 'priority',
                text => 1,
                field => 'name'
            },
            queue => {
                alias => 'me',
                text => 0,
                field => 'parent_pk1'
            },
            queue_name => {
                alias => 'queue',
                text => 1,
                field => 'name'
            },
            reporter => {
                alias => 'me',
                text => 1,
                field => 'identity_pk1'
            },
            reporter_email => {
                alias => 'person',
                text => 1,
                field => 'email'
            },
            reporter_name => {
                alias => 'person',
                text => 1,
                field => 'name'
            },
            type => {
                alias => 'type',
                text => 1,
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
    my @tickets = $self->create_resultset($oquery)->all;

    my $pager = Data::SearchEngine::Paginator->new(
        current_page => $oquery->page,
        entries_per_page => $oquery->count,
        total_entries => scalar(@tickets)
    );

    my %facets = ();
    for(0..scalar(@tickets) - 1) {
        my $tick = $tickets[$_];

        my $products = $tick->products;
        while(my $prod = $products->next) {
            $facets{product}->{$prod->name}++;
        }

        $facets{status}->{$tick->status->name}++;
        $facets{owner}->{$tick->owner->person->token}++;
        $facets{priority}->{$tick->priority->name}++;
        $facets{type}->{$tick->type->name}++;

        push(@items, Data::SearchEngine::Holistic::Item->new(
            id => $tick->id,
            ticket => $tick,
            score => 1
        )) if($_ + 1 >= $pager->first && $_ <= $pager->last);
    }

    my $results = Data::SearchEngine::Holistic::Results->new(
        query => $oquery,
        pager => $pager,
        items => \@items,
        elapsed => time - $start,
        facets => \%facets
    );
}

sub create_resultset {
    my ($self, $oquery) = @_;

    my $q = $self->query_parser->parse($oquery->query);

    my %conds = ();

    my %attrs = (
        prefetch => [
            'type',
            {
                #'queue' => { 'product_links' => 'product' },
                'ticket_tags' => 'tag',
                'final_state' => [
                    { 'identity' => 'person' },
                    { 'destination_identity' => 'person' } ,
                    'priority', 'status'
                ]
            }
        ],
    );

    # Create a list of ANDs that we can fiddle with later
    my @ands = ();

    if(exists($q->{''}) && scalar(@{ $q->{''} })) {
        my $ors = [];
        $self->add_conditions($q->{''}, $ors);
        $conds{'-or'} = $ors;
    }
    if(exists($q->{'+'}) && scalar(@{ $q->{'+'} })) {
        $self->add_conditions($q->{'+'}, \@ands);
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
    my ($self, $query, $conditions, $negate) = @_;

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
            push(@{ $conditions }, {
                'me.name' => { -like => "\%$val\%" },
            });
            push(@{ $conditions }, {
                'me.description' => { -like => "\%$val\%" },
            });
        } else {
            my $fdef = $fields->{$field};
            if($op eq ':' && !$fdef->{text}) {
                # :s are basically LIKEs.  If we are not dealing with a text
                # field then convert the op to a =
                $op = '=';
            }

            # If we got here, there must be a field

            # We can only do likes if it's text
            if($op eq ':' && $fdef->{text}) {
                if($negate) {
                    push(@{ $conditions }, {
                        $fdef->{alias}.'.'.$fdef->{field} => { '-not like' => "\%$val\%" }
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
            } elsif(($op eq '>') && !$fdef->{text}) {
                push(@{ $conditions }, {
                    $fdef->{alias}.'.'.$fdef->{field} => { '>' =>  $val }
                });
            } elsif(($op eq '<') && !$fdef->{text}) {
                push(@{ $conditions }, {
                    $fdef->{alias}.'.'.$fdef->{field} => { '<' =>  $val }
                });
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
