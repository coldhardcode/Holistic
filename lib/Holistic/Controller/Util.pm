package Holistic::Controller::Util;

use Moose;
use Try::Tiny;

use DateTime::Format::Natural;

BEGIN { extends 'Catalyst::Controller::REST' }

=head1 NAME

Holistic::Controller::Util - RESTful Utility Controller

=head1 METHODS

=cut

has 'datetime_parser' => (
    is => 'ro',
    lazy_build => 1,
    handles => {
        'parse_datetime' => 'parse_datetime',
        'parse_duration' => 'parse_datetime_duration'
    }
);

sub _build_datetime_parser {
    DateTime::Format::Natural->new;
}

sub setup : Chained('.') PathPart('util') CaptureArgs(0) { }

sub verify_date : Chained('setup') Args(0) ActionClass('REST') { }
sub verify_date_POST {
    my ( $self, $c, $data ) = @_;
    $data ||= $c->req->data || $c->req->params;

    my @valids;

    my $fmt_date = '%x';
    my $fmt_time = '%X';
#$c->user_exists ?
    my $tz  = $c->user_exists ? $c->user->person->timezone : $c->config->{timezone};

    if ( my $date = $data->{date} ) {
        my @dates = ref $date eq 'ARRAY' ? @$date : ( $date );
        foreach my $date ( @dates ) {
            $c->log->debug("Verifying: $date");
            try {
                my $dt = $self->parse_datetime( $date );
                $dt->set_time_zone( $tz ) if defined $tz;
                my $fmt;
                if ( $data->{format} ) {
                    $fmt = $data->{format};
                }
                elsif ( $dt->hour && $dt->minute && $dt->second ) {
                    $fmt = "$fmt_date $fmt_time";
                } else {
                    $fmt = $fmt_date;
                }
                push @valids, $dt->strftime($fmt);
            } catch {
                $c->log->error($_);
                push @valids, undef;
            };
        }
    }
    $c->log->debug($c->req->content_type);
    $c->log->_dump(\@valids);
    $self->status_ok( $c, entity => { date => \@valids } );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
