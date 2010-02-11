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

    $c->stash->{template} = 'calendar/default.tt';
}

sub day : Chained('setup') PathPart('') Args(3) {
    my ($self, $c, $year, $month, $day) = @_;

    # Use ->{now} because it is timezone'd already.
    my $req_day = $c->stash->{now};
        $req_day->year( $year );
        $req_day->month( $month );
        $req_day->day( $day );

    $c->stash->{req_day} = $req_day;
    $c->stash->{template} = 'calendar/day.tt';
}

#no Moose;
#__PACKAGE__->meta->make_immutable;

1;
