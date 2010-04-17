package Holistic::Base::Controller::REST;

use Moose;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    'default' => 'text/html',
    map => {
        'text/html'  => [ 'View', 'TT' ],
        'text/xhtml' => [ 'View', 'TT' ],
        # We do not suppor XML serialization, and this fixes Safari being
        # retarded.
        'text/xml'   => [ 'View', 'TT' ],
    },
    update_string => 'Your object has been updated.',
    create_string => 'Your object has been created.',
    error_string => 'There was an error creating your object.',
);

has 'scope' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_default_scope'

);

has 'access_check' => (
    is  => 'rw',
    isa => 'CodeRef',
    predicate => 'has_access_check'
);

has 'order_by' => (
    is  => 'rw',
    isa => 'Str',
    default => ''
);

has 'prefetch' => (
    is  => 'rw',
    isa => 'ArrayRef',
    default => sub { [] }
);

has 'create_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'Your object has been created.'
);

has 'update_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'Your object has been updated.'
);

has 'error_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'There was a problem processing your request.'
);

has 'rs_key' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'rs'
);

has 'object_key' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'object'
);

has 'class' => (
    is      => 'rw',
    isa     => 'Str'
);

has 'schema_class' => (
    is      => 'rw',
    isa     => 'Str'
);

has 'field_name_maps' => (
    is      => 'rw',
    isa     => 'HashRef|ArrayRef'
);

sub setup : Chained('.') PathPart('') CaptureArgs(0) { 
    my ( $self, $c ) = @_;
    $c->stash->{ $self->rs_key } = $self->_fetch_rs( $c );
}

sub _fetch_rs {
    my ( $self, $c ) = @_;

    my $rs = $c->model($self->class)->search({}, { prefetch => $self->prefetch });

    unless ( $rs and $rs->isa('DBIx::Class::ResultSet') ) {
        die "Invalid configuration, asked for " . 
            $self->class . " but didn't get a resultset back.\n";
    }

    return $rs;
}

sub create_form : Chained('setup') PathPart('create') Args(0) { 
    my ( $self, $c ) = @_;

    if ( $self->has_access_check ) {
        try {
            $self->access_check( $c );
        } catch {
            $c->detach('access_denied');
        };
    }
    $c->stash->{scope} = 'create';
    $c->stash->{template} = $c->action->namespace . "/create_form.tt";
}

sub root : Chained('setup') PathPart('') Args(0) ActionClass('REST') {
    my ( $self, $c ) = @_;

    if ( $self->can("setup_search") ) {
        $c->stash->{$self->rs_key} = $self->setup_search({ 
            rs => $c->stash->{ $self->rs_key}, 
            params => $c->req->params 
        });
    }
}

sub search : Chained('setup') PathPart('search') Args(0) ActionClass('REST') { }

sub search_GET {
    my ( $self, $c ) = @_;

    my $data = $c->req->data || $c->req->params;
    my $results = int($data->{results} || 25);
        $results = 25 if int($results) < 1 or int($results) > 25;
    my $page = $data->{page} || 1;
        $page = 1 if int($page) < 1;

    if ( my $index = $data->{startIndex} ) {
        if ( $index > 0 ) {
            $page = int($index / $results) + 1;
            $c->log->debug("$index / $results = $page") if $c->debug;
        }
    }

    my $search  = $data->{search};
        $search = {} unless defined $search and ref $search eq 'HASH';

    foreach my $key ( keys %$search ) {
        delete $search->{$key} unless $search->{$key};

        # Flatten prefetches (just works to one level now...)
        if ( ref $search->{$key} eq 'HASH' ) {
            foreach my $prefetch_key ( keys %{ $search->{$key} } ) {
                next unless $search->{$key}->{$prefetch_key};
                $search->{"$key.$prefetch_key"} = $search->{$key}->{$prefetch_key};
            }
            delete $search->{$key};
        }
    }
    if ( $data->{filter} and my $type = $data->{filter}->{type} ) {
        if ( lc($type) eq 'like' ) {
            my @keys = keys %$search;
            if ( $data->{filter}->{keys} ) {
                @keys = ref $data->{filter}->{keys} eq 'ARRAY' ?
                    @{ $data->{filter}->{keys} } : ( $data->{filter}->{keys} );
            }
            foreach my $key ( @keys ) {
                $search->{$key} = { 'LIKE', '%' . $search->{$key} . '%' };
            }
        }
    }

    my $sort_by = $data->{sort} || $self->order_by;
    my $dir     = uc($data->{dir}) eq 'ASC' ? 'asc' : 'desc';
    $c->stash->{search} = $search;
    # Hacky:
    $sort_by    = "me.$sort_by" if $sort_by and $sort_by !~ /\./;

    my $paged = 1;
    my $extra = { 
        prefetch    => $self->prefetch,
        page        => $page, 
        rows        => $results,
        # Since we need quoting, pass a scalar ref into SQL::Abstract
        order_by    => \($sort_by . " " . uc($dir))
    };

    if ( $c->req->params->{download} ) {
        delete $extra->{page};
        delete $extra->{rows};
        $paged = 0;
    }
    if ( $c->log->debug ) {
        $c->log->_dump($search);
        $c->log->_dump($extra);
    }
    my $rs = $c->forward('perform_search', [ $search, $extra ]);

    $c->stash->{sort_by} = $sort_by;
    $c->stash->{dir}     = lc($dir);
    $c->stash->{pager}   = $rs->pager if $paged;

    if ( $c->req->looks_like_browser ) {
        $c->stash->{context}->{search} = $rs;
    } else {
        $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
        my $pageSize = $paged ? $c->stash->{pager}->entries_on_this_page : 0;
        my $records = [ $rs->all ];    
        $self->status_ok( $c, 
            entity => {
                totalRecords => $paged ?
                    int($c->stash->{pager}->total_entries) : scalar(@$records),
                startIndex   => $paged ?
                    ( $c->stash->{pager}->entries_per_page * ( $c->stash->{pager}->current_page - 1 ) ) : 1,
                pageSize        => $pageSize,
                sort            => $c->stash->{sort_by} || '',
                dir             => lc($c->stash->{dir} || 'desc'),
                records         => $records,
            }
        );
    }
}

sub perform_search : Private {
    my ( $self, $c, @args ) = @_;
    return $c->stash->{ $self->rs_key }->search( @args );
}

sub root_GET { }

sub root_POST {
    my ( $self, $c, $data ) = @_;
    $data ||= $c->req->data || $c->req->params;
    delete $data->{x};
    delete $data->{y};

    $c->forward('create', [ $data ]);

    if ( defined ( my $object = $c->stash->{$self->object_key} ) ) {
        $c->forward('post_action', [ $object ]);
    }
}

sub object_setup : Chained('setup') PathPart('id') CaptureArgs(1) { 
    my ( $self, $c, $id ) = @_;
    my $obj = $c->stash->{ $self->rs_key }->find( $id );
    $c->stash->{scope} = 'update';

    unless ( $obj ) {
        $c->forward('not_found');
        $c->detach if $c->req->looks_like_browser;
        return $self->status_not_found( $c, message => $c->loc("Sorry, unable to find that object") );
    }
    $c->stash->{$self->object_key} = $obj;
}

sub object : Chained('object_setup') PathPart('') Args(0) ActionClass('REST') { }

sub object_GET { }
sub object_POST {
    my ( $self, $c, $data ) = @_;

    $data ||= $c->req->data || $c->req->params;
    delete $data->{x};
    delete $data->{y};

    my $obj = $c->stash->{$self->object_key};

    if ( $obj ) {
        $c->forward('update', [ $obj, $data ]);
    } else {
        $c->forward('create', [ $data ]);
    }
    $c->forward('post_action');
}

sub update : Private {
    my ( $self, $c, $object, $data ) = @_;

    my $page   = delete $data->{_page};
    my $scopes = delete $data->{scopes};
    $scopes = [ $self->scope ]
        if not defined $scopes and $self->has_default_scope;

    $scopes = ref $scopes ? $scopes : [ $scopes ];

    $data = $self->prepare_data( $c, $data );

    my $no_fails = 0;
    my $schema = $c->model('Schema')->schema;
    try {
        $schema->txn_do( sub {
            foreach my $scope ( @$scopes ) {
                my $chunk     = delete $data->{$scope};
                my $scope_obj = $c->stash->{context}->{$scope};
                unless ( defined $scope_obj ) {
                    $c->log->error("Scope $scope not defined in stash.context, skipping update");
                    next;
                }
                $c->log->debug("Verifying scope: $scope (". $scope_obj->id .")")
                    if $c->debug;
                my $results = $c->model('DataManager')->verify( $scope, $chunk );
                if ( $results->success ) {
                    my $clean_data = $c->model('DataManager')->data_for_scope( $scope );
                    delete $clean_data->{verify_password}
                        if exists $clean_data->{verify_password};
                    $c->log->debug("Updating $scope (" . $scope_obj->id . ")")
                        if $c->debug;
                    $scope_obj->update($clean_data);
                } else {
                    $c->log->debug("No success verifying scope $scope") if $c->debug;

                    $no_fails = 1;
                    $c->stash->{form}->{valids} = $c->model('DataManager')->data_for_scope( $scope );
                }
            }
            if ( $no_fails ) {
                die "validation error\n";
            }
            $c->message( $self->update_string );
        } );
    } catch {
        $c->log->error("Caught error: $_");
        $c->message({
            type    => 'error',
            message => $self->error_string
        });
        foreach my $message ( @{ $c->model('DataManager')->messages->messages } ) {
            $c->message($message);
        }
        my $uri = $page->{referrer};
        if ( $uri ) {
            $uri = URI->new( $uri );
            unless ( $uri->host eq $c->req->uri->host ) {
                $uri = undef;
            }
        }
        $c->res->redirect( $uri || $c->req->uri );
        $c->detach;
    };
}

# Just designed to override this.
sub prepare_data { shift; shift; $_[0]; }

sub create : Private {
    my ( $self, $c, $data ) = @_;

    my $page   = delete $data->{_page};
    my $scopes = delete $data->{scopes};

    $scopes = [ $self->scope ]
        if not defined $scopes and $self->has_default_scope;
    $scopes = ref $scopes ? $scopes : [ $scopes ];

    my $no_fails = 0;
    my @objects  = ();
    my $schema   = $c->model('Schema')->schema;

    $data = $self->prepare_data( $c, $data );

    try {
        @objects = $schema->txn_do( sub {
            my @objects;
            foreach my $scope ( @$scopes ) {
                my $chunk   = delete $data->{$scope};
                $c->log->debug("Verifying $scope (we have chunk: $chunk)")
                    if $c->debug;
                $c->log->_dump({ $scope => $chunk }) if $c->debug;

                my $results = $c->model('DataManager')->verify( $scope, $chunk );
                $c->log->debug("$scope results: " . $results->success);
                if ( $results->success ) {
                    my $clean_data = $c->model('DataManager')->data_for_scope( $scope );
                    delete $clean_data->{verify_password}
                        if exists $clean_data->{verify_password};
                    $c->log->debug("Creating $scope...")
                        if $c->debug;
                    push @objects,
                        $c->stash->{$self->rs_key}->create($clean_data);
                    $c->stash->{context}->{$scope} = $objects[-1];
                    if ( $scope eq $self->object_key ) {
                        $c->stash->{$self->object_key} = $objects[-1];
                    }
                } else {
                    if ( $c->debug ) {
                        $c->log->debug("No success verifying scope $scope");
                        $c->log->_dump({
                            missing => [ $results->missings ],
                            invalids => [ $results->missings ],
                        });
                    }

                    $no_fails = 1;
                    $c->stash->{form}->{valids} = $c->model('DataManager')->data_for_scope( $scope );
                }
            }
            if ( $no_fails ) {
                die "validation error\n";
            }
            $c->message( $self->create_string );
            return @objects;
        } );
    } catch {
        $c->log->error("Caught error: $_");
        $c->message({
            type    => 'error',
            message => $self->error_string
        });
        foreach my $message ( @{ $c->model('DataManager')->messages->messages } ) {
            $c->message($message);
        }
        my $uri = $page->{referrer};
        if ( $uri ) {
            $uri = URI->new( $uri );
            unless ( $uri->host eq $c->req->uri->host ) {
                $uri = undef;
            }
        } else {
            $uri = $c->uri_for( $c->controller->action_for('create_form'), $c->req->captures );
        }
        $c->log->debug("Redirecting... $uri");
        $c->log->_dump( $c->error );
        $c->res->redirect( $uri || $c->req->uri );
        $c->detach;
    };
}

sub post_create : Private { }
sub post_update : Private { }

sub post_action : Private {
    my ( $self, $c, $object ) = @_;

    if ( $c->req->looks_like_browser ) {
        my $uri = $c->req->uri;
        if ( defined $object and defined $c->controller->action_for('object') ) {
            $uri = $c->uri_for_action(
                $self->action_for('object'),
                [ @{ $c->req->captures || [] }, $object->id ]
            );
        }
        $c->res->redirect( $uri, 303 );
    } else {
        my $object = $c->stash->{$self->object_key};
        if ( defined $object ) {
            return $self->status_ok( $c, entity => { $object->get_columns } );
        } else {
            return $self->status_ok( $c );
        }
    }
}

sub setup_search {
    my ( $self, $p ) = @_;
    my $rs       = $p->{rs};
    my $params   = $p->{params};
    my $base     = $p->{base} || '';

    my $source ||= $rs->result_source;
    
    my %search_params = 
        map { 
            my $value = $params->{$_};
            if ( $value =~ /LIKE:(.*)?$/ ) {
                $value = { LIKE => $1 };
            }
            elsif ( $value =~ /BETWEEN:(.*);(.*)$/ ) {
                $value = { -between => [ $1, $2 ] };
            }
            ( $base ? join('.', $base, $_) : $_ ) => $value;
        }
        grep { exists $params->{$_} }
        $source->columns;

    my %join_params = ();

    $rs->search({ %search_params }, { %join_params });
}

sub access_denied : Private {
    my ( $self, $c ) = @_;
    $c->res->status(403);
    $c->stash->{template} = $c->action->namespace . "/create_form.tt";
    $c->detach;
}

sub not_found : Private { 
    my ( $self, $c ) = @_;

    $c->res->status(404);
    $c->stash->{template} = $c->action->namespace . "/not_found.tt";
}

sub end : ActionClass('Serialize') { }

no Moose;
__PACKAGE__->meta->make_immutable;
