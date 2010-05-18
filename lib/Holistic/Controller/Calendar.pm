package Holistic::Controller::Calendar;

#use Moose;

use parent 'Holistic::Base::Controller';

use DateTime;
use DateTime::Duration;

sub setup : Chained('.') PathPart('calendar') CaptureArgs(0) { }

sub root : Chained('setup') PathPart('') Args() {
    my ($self, $c, $year, $month) = @_;

    my $now = $c->stash->{now};
    if ( $year && $month ) {
        $now->year($year);
        $now->month($month);
        $now->day(1);
    }
    $c->stash->{req_day} = $now;

    my $ldom = DateTime->last_day_of_month(
        month => $now->month,
        year => $now->year
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
    $c->stash->{days} = \@days;
}

sub today : Chained('setup') PathPart('today') Args(0) {
    my ($self, $c) = @_;

    my $now = $c->stash->{now};

    $c->stash->{template} = 'calendar/day.tt';

    $c->detach('day', [ $now->year, $now->month, $now->day ]);
}

sub day : Chained('setup') PathPart('') Args(3) {
    my ($self, $c, $year, $month, $day) = @_;

    # Use ->{now} because it is timezone'd already.
    my $req_day = $c->stash->{now}->clone;
        $req_day->set_year($year);
        $req_day->set_month($month);
        $req_day->set_day($day);

    $c->stash->{req_day} = $req_day;

    my $states = $c->model('Schema::Ticket::Change')->search(
        {
            'me.dt_created' => { -between => [
                $req_day->strftime('%F').' 00:00:00',
                $req_day->strftime('%F').' 23:59:59',
            ] }
        }, {
            prefetch => 'ticket'
        });
    $c->stash->{changes} = [ $states->all ];
}

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;
