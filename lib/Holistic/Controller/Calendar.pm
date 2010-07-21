package Holistic::Controller::Calendar;
use strict;

#use Moose;

use parent 'Holistic::Base::Controller';

use DateTime;
use DateTime::Duration;
use DateTime::Format::ICal;
use Try::Tiny;

use Data::ICal;
use Data::ICal::Entry::Event;
use Data::SearchEngine::Holistic::Changes;
use Data::SearchEngine::Holistic::Query;

sub setup : Chained('.') PathPart('calendar') CaptureArgs(0) { }

sub ical : Chained('setup') PathPart('ical') Args(0) {
    my ($self, $c) = @_;

    my $markers = $c->model('Schema::TimeMarker')->search(
        {
            dt_marker => { '>' => \'NOW()' }
        }, {
            order_by => 'dt_marker',
        }
    );

    my $cal = Data::ICal->new;
    while(my $marker = $markers->next) {

        # Customize the name and whatnot for the different objects we could
        # be talking about.
        my ($summ, $url, $desc);
        if($marker->rel_source eq 'queues') {
            $summ = $c->loc("Queue '[_1]' [_2]", $marker->queue->name, $c->system_localize($marker->name));
            $url = $c->uri_for_action('/queue/object', [ $marker->foreign_pk1 ]);
            $desc = $marker->queue->description;
        } else {
            $summ = $c->loc("Ticket #[_1] [_2]", $marker->foreign_pk1, $c->system_localize($marker->name));
            $url = $c->uri_for_action('/ticket/object', [ $marker->foreign_pk1 ]);
            $desc = $marker->ticket->name;
        }

        my $todo = Data::ICal::Entry::Event->new;
        $todo->add_properties(
            summary => $summ,
            url => $url,
            description => $desc,
            dtstart => DateTime::Format::ICal->format_datetime($marker->dt_marker)
        );
        $cal->add_entry($todo);
    }

    $c->res->headers->header('Content-type: text/calendar"');
    $c->res->headers->header('Content-Disposition: attachment; filename="Holistic Schedule.pdf"');
    $c->res->body($cal->as_string);
}

sub root : Chained('setup') PathPart('') Args() {
    my ($self, $c, $year, $month) = @_;

    my $now = $c->stash->{now};
    my $req_day = $now->clone;
    if ( $year && $month ) {
        $req_day->set_year($year);
        $req_day->set_month($month);
        $req_day->set_day(1);
    }
    $c->stash->{req_day} = $req_day;

    my $ldom = DateTime->last_day_of_month(
        month => $req_day->month,
        year => $req_day->year
    );
    my $fdom = $ldom->clone->subtract_duration(DateTime::Duration->new(
        months => 1
    ));
    $fdom->add({ days => 1 });

    my @days = ();
    if($fdom->day_of_week != 7) {

        my $prev_day = $fdom->clone->subtract_duration(
            DateTime::Duration->new(days => 1)
        );
        my $currday = $prev_day;
        push(@days, $currday);
        while($currday->day_of_week != 7) {
            $currday = $currday->clone->subtract_duration(DateTime::Duration->new(
                days => 1
            ));
            push(@days, $currday);
        }
        # Reverse the days, since we counted back.
        @days = reverse(@days);
        $c->stash->{prev_day} = $prev_day;
    }

    my $currday = $fdom;
    $c->stash->{first_day} = $fdom;
    while($currday->day != $ldom->day) {
        push(@days, $currday);
        $currday = $currday->clone->add_duration(DateTime::Duration->new(
            days => 1
        ));
    }
    push(@days, $ldom);

    $c->stash->{next_day} = $ldom->clone->add_duration(
        DateTime::Duration->new(days => 1)
    );
    if($ldom->day_of_week != 6) {
        my $currday = $c->stash->{next_day};
        while($currday->day_of_week != 7) {
            push(@days, $currday);
            $currday = $currday->clone->add_duration(DateTime::Duration->new(
                days => 1
            ));
        }
    }

	my $markers = $c->model('Schema::TimeMarker')->search(
		{
			dt_marker => { between => [ $fdom->ymd.' 00:00:00', $ldom->ymd.' 23:59:59' ]}
		}, {
			# This doesn't work at all...
			#prefetch => [ 'ticket', 'queue' ]
			order_by => 'rel_source', 'dt_marker',
		}
	);

	my %mark_days;
	while(my $marker = $markers->next) {
		my $ymd = $marker->dt_marker->ymd;
		$mark_days{$ymd} = [] unless defined($mark_days{$ymd});
		push(@{ $mark_days{$ymd} }, $marker);
		last if(scalar(@{ $mark_days{$ymd} }) >= 3);
	}

	$c->stash->{markers} = \%mark_days;
    $c->stash->{days} = \@days;
    $c->stash->{template} = 'calendar/root.tt';
}

sub today : Chained('setup') PathPart('today') Args(0) {
    my ($self, $c) = @_;

    my $now = $c->stash->{now};

    $c->stash->{template} = 'calendar/day.tt';

    $c->detach('day');
}

sub day : Chained('setup') PathPart('day') Args(0) {
    my ($self, $c) = @_;

    my $req_day;
    try { $req_day = DateTime::Format::DateParse->parse_datetime($c->req->params->{date_on}); };

    $c->stash->{req_day} = $req_day;

    my $markers = $c->model('Schema::TimeMarker')->search(
      {
          dt_marker => { between => [ $req_day->ymd.' 00:00:00', $req_day->ymd.' 23:59:59' ]}
      }, {
          # This doesn't work at all...
    #       #prefetch => [ 'ticket', 'queue' ]
          order_by => 'rel_source', 'dt_marker',
      }
    );

    $c->stash->{markers} = [ $markers->all ];


    my $search = Data::SearchEngine::Holistic::Changes->new(
        schema => $c->model('Schema')->schema
    );

    my $query = Data::SearchEngine::Holistic::Query->new(
        original_query => '*:*',
        query => '*:*',
        page => $c->req->params->{page} || 1,
        count => $c->req->params->{count} || 10,
    );

    my @filters = qw(date_on owner queue_name);
    foreach my $filter (@filters) {
        if($c->req->params->{$filter}) {
            $query->set_filter($filter, $c->req->params->{$filter});
        }
    }

    $c->detach('root') unless $query->has_filters;

    $c->stash->{results} = $search->search($query);
}

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;
