package Holistic::Schema::Ticket;

use Moose;

use Carp;
use String::Random;

extends 'Holistic::Base::DBIx::Class';

__PACKAGE__->table('tickets');
#$CLASS->resultset_class('Holistic::ResultSet::Ticket');

__PACKAGE__->add_columns(
    'pk1',
    { data_type => 'integer', size => '16', is_auto_increment => 1 },
    'token',
    { data_type => 'varchar', size => '255', is_nullable => 0 },
    'name',
    { data_type => 'varchar', size => '255', is_nullable => 0, },
);

__PACKAGE__->set_primary_key('pk1');

__PACKAGE__->has_many('states', 'Holistic::Schema::Ticket::State', 'ticket_pk1');

__PACKAGE__->might_have('final_state', 'Holistic::Schema::Ticket::FinalState', 'ticket_pk1');

sub state {
    my ( $self ) = @_;

    my $final_state = $self->final_state;

    my $rs = $self->states(
        {},
        {
            prefetch => [ 'actor_role', 'actor' ],
            order_by => [ { '-asc' => 'dt_created' } ] 
        }
    );

    my $state_count = $rs->count;

    return undef if $state_count == 0;

    if ( not defined $final_state or $state_count != $final_state->state_count )
    {
        my %merge;
        my @columns = $rs->result_source->columns;

        my %aggregate_columns;
        my %persistent_columns;
        my %normal_columns;

        foreach my $col_name ( @columns ) {
            my $info = $rs->result_source->column_info( $col_name );
            next if $info->{is_auto_increment};

            $col_name = $info->{accessor} if defined $info->{accessor};

            if ( $info->{persist_state} ) {
                $persistent_columns{ $col_name } = $info->{persistent_state};
            }
            elsif ( $info->{aggregate_state} ) {
                $aggregate_columns{ $col_name } = $info->{aggregate_state};
            }
            else {
                $normal_columns{ $col_name } = $col_name;
            }
        }

        while ( my $row = $rs->next ) {
            foreach my $column ( keys %aggregate_columns ) {
                my $type = $aggregate_columns{$column};
                    $type = 'sum' if int($type) == 1;

                if ( $type eq 'sub' ) {
                    $merge{$column} -= $row->$column;
                } else {
                    $merge{$column} += $row->$column;
                }
            }
            foreach my $column ( keys %persistent_columns ) {
                $merge{$column} ||= $row->$column;
            }
            foreach my $column ( keys %normal_columns ) {
                $merge{$column} = $row->$column;
            }
        }

        $merge{state_count} = $state_count;
        $final_state = $self->create_related('final_state', \%merge);
    }

    return $final_state;
}


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
