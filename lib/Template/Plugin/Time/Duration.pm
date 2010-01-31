package Template::Plugin::Time::Duration;
use strict;

our $VERSION = '0.01';

require Template::Plugin;
use base qw(Template::Plugin);

use Time::Duration qw();

sub ago { shift; return Time::Duration::ago(@_) };

sub ago_exact { shift; return Time::Duration::ago_exact(@_) };

sub concise { shift; return Time::Duration::concise(@_) };

sub duration { shift; return Time::Duration::duration(@_); }

sub duration_exact { shift; return Time::Duration::duration_exact(@_); }

sub from_now { shift; return Time::Duration::from_now(@_) };

sub from_now_exact { shift; return Time::Duration::from_now_exact(@_) };

sub later { shift; return Time::Duration::later(@_) };

sub later_exact { shift; return Time::Duration::later_exact(@_) };

sub earlier { shift; return Time::Duration::earlier(@_) };

sub earlier_exact { shift; return Time::Duration::earlier_exact(@_) };

1;