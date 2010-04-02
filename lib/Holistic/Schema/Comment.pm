package Holistic::Schema::Comment;
    
use Moose;
use Try::Tiny;

extends 'Holistic::Base::DBIx::Class';

my $CLASS = __PACKAGE__; 

$CLASS->load_components( qw/
    Tree::AdjacencyList Serialize::Storable TimeStamp DynamicDefault Core
/ );
$CLASS->table('comments');

$CLASS->add_columns(
    pk1  => {
        data_type   => 'integer',
        is_nullable => 0,
        size        => 16,
        is_auto_increment => 1,
    },  
    parent_pk1 => {
        data_type       => 'integer',
        is_nullable     => 0,
        default_value   => 0,
        size            => 16,
        dynamic_default_on_create => sub {
            shift->result_source->schema->default_comment->id;
        }
    },  
    identity_pk1 => {
        data_type       => 'integer',
        is_nullable     => 0,
        default_value   => 0,
        size            => 16,
    },
    taggable_pk1 => {
        data_type   => 'integer',
        is_nullable => 1,
        size        => undef,
        is_foreign_key => 1
    },
    name => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 255,
    },
    class => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 128,
    },
    body => {
        data_type   => 'text',
        is_nullable => 1
    },
    dt_created => {
        data_type   => 'datetime',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1
    }
);

$CLASS->set_primary_key('pk1');
$CLASS->parent_column('parent_pk1');

$CLASS->has_many(
    'parent_discussable_comments' => 'Holistic::Schema::DiscussableComment',
    { 'foreign.comment_pk1' => 'self.parent_pk1' },
    { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
$CLASS->has_many(
    'discussable_comments' => 'Holistic::Schema::DiscussableComment',
    { 'foreign.comment_pk1' => 'self.pk1' },
    { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

$CLASS->many_to_many('comments', 'discussable_comment', 'comment');
$CLASS->many_to_many('comment_objects', 'discussable_comments', 'discussable');

$CLASS->belongs_to(
    'identity', 'Holistic::Schema::Person::Identity', 
    { 'foreign.pk1' => 'self.identity_pk1' }
);

$CLASS->might_have(
    'parent' => 'Holistic::Schema::Comment',
    { 'foreign.pk1' => 'self.parent_pk1' },
    { cascade_delete => 0 }
);

sub objects {
    my $self = shift();

    my @objects;

    my $comments_rs = $self->comments();
    while ( my $comment = $comments_rs->next() ) {
        push @objects, $comment->comments_rs->all;
    }
    return \@objects;
}

sub add_comment {
    my ( $self, $data ) = @_;

    my $comments_rs = $self->children;
    my $schema      = $self->result_source->schema;

    # This will throw an exception on data error
    $comments_rs->validate( $data );

    $data->{parent_pk1} = $self->id;
    my $comment;
    try {
        $comment = $self->add_to_children($data);
    } catch {
        # Should we do anything here?
        die $_;
    };
    return $comment;
}

1;

