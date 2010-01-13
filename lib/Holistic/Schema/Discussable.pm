package Holistic::Schema::Discussable;
    
use Moose;
    
extends 'Holistic::Base::DBIx::Class';
        
my $CLASS = __PACKAGE__;
        
$CLASS->table('discussables');
$CLASS->add_columns(
    pk1  => {
        data_type   => 'INTEGER',
        is_nullable => 0,
        size        => 16,
        is_auto_increment => 1,
    },  
    result_class => {
        data_type   => 'VARCHAR',
        size        => 255,
        is_nullable => 0,
    },
    dt_created => {
        data_type   => 'DATETIME',
        is_nullable => 0,
        size        => undef,
        set_on_create => 1 
    }
);  
    
$CLASS->set_primary_key('pk1');

$CLASS->has_many(
    'discussable_comments' => 'Holistic::Schema::DiscussableComment', 
    { 'foreign.discussable_pk1' => 'self.pk1' }
);
$CLASS->many_to_many('comments' => 'discussable_comments', 'comment');

sub root_topic_rs {
    my ($self) = @_;

    my $parent = $self->result_source->schema->resultset('Comment')
        ->search({ name => 'Root', parent_pk1 => 0 })->single;
    my $rs = $self->threads->search(
        { 'thread.parent_pk1' => $parent->id },
        { order_by => \'me.dt_created DESC' }
    );
    return $rs;
}

sub all_comments_rs {
    my ( $self ) = @_;

    if ( my $rs = $self->result_class ) {
        my $obj = eval {
            $self->result_source->schema->resultset($rs)
                ->search({ discussable_pk1 => $self->pk1 });
        };
        return $obj;
    }
}

1;

