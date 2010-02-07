package Holistic::Controller::Calendar;

use parent 'Catalyst::Controller';

use Moose;

use DateTime;
use DateTime::Duration;

sub base : Chained('../calendar') PathPart('calendar') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

sub default : Chained('base') PathPart('') Args() {
    my ($self, $c, $year, $month) = @_;

    my $now = $c->stash->{now};
    if($year && $month) {
        $now = DateTime->new(year => $year, month => $month, day => 1);
    }

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
        my $currday = $prev_day->clone->subtract_duration(
            DateTime::Duration->new(days => 6 - $prev_day->day_of_week)
        );
        while($currday->day != $fdom->day) {
            push(@days, $currday);
            $currday = $currday->clone->add_duration(DateTime::Duration->new(
                days => 1
            ));
        }
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

sub day : Chained('base') PathPart('day') Args() {
    my ($self, $c, $year, $month, $day) = @_;

    my $day = DateTime->now;
    if($year && $month && $day) {
        $day = DateTime->new(year => $year, month => $month, day => $day);
    }

    $c->stash->{template} = 'calendar/day.tt';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
