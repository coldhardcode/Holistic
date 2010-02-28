package Data::SearchEngine::Holistic::Query;
use Moose;
use MooseX::UndefTolerant;
use Moose::Util::TypeConstraints;

extends 'Data::SearchEngine::Query';

coerce 'ArrayRef'
    => from 'Str'
    => via { [ int($_) ] };

coerce 'ArrayRef'
    => from 'Num'
    => via { [ int($_) ] };

has requester => (
    is => 'ro',
    isa => 'ArrayRef',
    coerce => 1,
    predicate => 'has_requestor'
);

1;