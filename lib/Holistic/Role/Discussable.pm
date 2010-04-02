package Holistic::Role::Discussable;

use Moose::Role;
use Carp;

requires 'table';

=head1 NAME

Holistic::Roles::Discussable - Role to implement discussion actions on a class

=head1 SYNOPSIS

First, simply apply the role to your L<DBIx::Class> package, as follows:

 package Holistic::Schema::Something;

 use Moose;

 extends 'Holistic::Base::DBIx::Class';

 with 'Holistic::Roles::Discussable';

 ...

Now, when using the class you have a variety of actions regarding discussions:

 my $something = $schema->resultset('Something')->first;

 # Return a DBIx::Class::ResultSet of all comments
 $something->comments;

 # Add a comment to $something
 $something->add_comment( ... );

 # Delete all comments
 $something->comments->delete;

=head2 REQUIREMENTS

This requires the addition of a discussable_pk1 column to the table of the
source object.  This role automatically adds the definition, so if you
deploy using DBIx::Class and SQL::Translator, everything is done for you!

This requires implementing a Discussable join table.

=head2 discussable_result_source

To override the default of 'Discussable', overrride this sub:

 sub discussable_result_source { 'CustomJoinTable' }

=cut


sub discussable_result_source { 'Discussable' }

after 'table' => sub {
    my ( $class ) = @_;

    $class->add_columns(
        discussable_pk1 => {
            data_type   => 'INTEGER',
            is_nullable => 1,
            size        => undef,
            is_foreign_key => 1
        },
    );

    $class->belongs_to(
        'discussable'   => $class->discussable_result_source,
        { 'foreign.pk1' => 'self.discussable_pk1' },
        { proxy => [ qw/comments/ ] }
    );
};

before 'insert' => sub {
    my ( $self ) = @_;
    unless ( defined $self->discussable_pk1 ) {
        my $discussable = $self->result_source->schema
            ->resultset('Discussable')
            ->find_or_create({ result_class => $self->result_class });

        $self->discussable_pk1( $discussable->id );
    }
};


=head2 add_comment

Add a comment.  Pretty simple!

=cut

sub add_comment {
    my $self = shift;
    my $data = shift;
    
    my $schema = $self->result_source->schema();

    # Unify the API here a bit. 
    if ( $data->{subject} and not $data->{name} ) {
        $data->{name} = delete $data->{subject};
    }
    for ( qw/body identity/ ) { 
        Carp::croak( "Need $_ to create comment" ) unless $data->{$_}
    }

    use Moose::Util;
    # Only do ACL checks on local idents, if it isn't local it is coming from
    # conduits like git, etc.
    if (
        Moose::Util::does_role($self, 'Holistic::Roles::ACL')
            &&
        $data->{identity}->realm eq 'local'
    ) {
        Carp::croak
        unless $self->check_access( $data->{identity}->person, 'comment' );
    }

    my $discussion = $schema->resultset('Comment')->create($data);
   
    my $dt = $schema->resultset('DiscussableComment')->find_or_create({
        comment_pk1     => $discussion->id(),
        discussable_pk1 => $self->discussable_pk1()
    });

    return $discussion;
}

1;
