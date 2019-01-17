package Mojolicious::Plugin::Yancy;
our $VERSION = '1.023';
# ABSTRACT: Embed a simple admin CMS into your Mojolicious application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://postgres@/mydb',
        collections => { ... },
    };

    ## With custom auth routine
    use Mojo::Base 'Mojolicious';
    sub startup {
        my ( $app ) = @_;
        my $auth_route = $app->routes->under( '/yancy', sub {
            my ( $c ) = @_;
            # ... Validate user
            return 1;
        } );
        $app->plugin( 'Yancy', {
            backend => 'pg://postgres@/mydb',
            collections => { ... },
            route => $auth_route,
        });
    }

=head1 DESCRIPTION

This plugin allows you to add a simple content management system (CMS)
to administrate content on your L<Mojolicious> site. This includes
a JavaScript web application to edit the content and a REST API to help
quickly build your own application.

=head1 CONFIGURATION

For getting started with a configuration for Yancy, see
L<Yancy::Help::Config>.

Additional configuration keys accepted by the plugin are:

=over

=item backend

In addition to specifying the backend as a single URL (see L<"Database
Backend"|Yancy::Help::Config/Database Backend>), you can specify it as
a hashref of C<< class => $db >>. This allows you to share database
connections.

    use Mojolicious::Lite;
    use Mojo::Pg;
    helper pg => sub { state $pg = Mojo::Pg->new( 'postgres:///myapp' ) };
    plugin Yancy => { backend => { Pg => app->pg } };

=item route

A base route to add Yancy to. This allows you to customize the URL
and add authentication or authorization. Defaults to allowing access
to the Yancy web application under C</yancy>, and the REST API under
C</yancy/api>.

=item return_to

The URL to use for the "Back to Application" link. Defaults to C</>.

=item filters

A hash of C<< name => subref >> pairs of filters to make available.
See L</yancy.filter.add> for how to create a filter subroutine.

=back

=head1 HELPERS

This plugin adds some helpers for use in routes, templates, and plugins.

=head2 yancy.config

    my $config = $c->yancy->config;

The current configuration for Yancy. Through this, you can edit the
C<collections> configuration as needed.

=head2 yancy.backend

    my $be = $c->yancy->backend;

Get the currently-configured Yancy backend object. See L<Yancy::Backend>
for the methods you can call on a backend object and their purpose.

=head2 yancy.route

Get the root route where the Yancy CMS will appear. Useful for adding
authentication or authorization checks:

    my $route = $c->yancy->route;
    my @need_auth = @{ $route->children };
    my $auth_route = $route->under( sub {
        # ... Check auth
        return 1;
    } );
    $auth_route->add_child( $_ ) for @need_auth;

=head2 yancy.plugin

Add a Yancy plugin. Yancy plugins are Mojolicious plugins that require
Yancy features and are found in the L<Yancy::Plugin> namespace.

    use Mojolicious::Lite;
    plugin 'Yancy';
    app->yancy->plugin( 'Auth::Basic', { collection => 'users' } );

You can also add the Yancy::Plugin namespace into the default plugin
lookup locations. This allows you to treat them like any other
Mojolicious plugin.

    # Lite app
    use Mojolicious::Lite;
    plugin 'Yancy', ...;
    unshift @{ app->plugins->namespaces }, 'Yancy::Plugin';
    plugin 'Auth::Basic', ...;

    # Full app
    use Mojolicious;
    sub startup {
        my ( $app ) = @_;
        $app->plugin( 'Yancy', ... );
        unshift @{ $app->plugins->namespaces }, 'Yancy::Plugin';
        $app->plugin( 'Auth::Basic', ... );
    }

Yancy does not do this for you to avoid namespace collisions.

=head2 yancy.list

    my @items = $c->yancy->list( $collection, \%param, \%opt );

Get a list of items from the backend. C<$collection> is a collection
name. C<\%param> is a L<SQL::Abstract where clause
structure|SQL::Abstract/WHERE CLAUSES>. Some basic examples:

    # All people named exactly 'Turanga Leela'
    $c->yancy->list( people => { name => 'Turanga Leela' } );

    # All people with "Wong" in their name
    $c->yancy->list( people => { name => { like => '%Wong%' } } );

C<\%opt> is a hash of options with the following keys:

=over

=item * limit - The number of items to return

=item * offset - The number of items to skip before returning items

=back

See L<the backend documentation for more information about the list
method's arguments|Yancy::Backend/list>. This helper only returns the list
of items, not the total count of items or any other value.

This helper will also filter out any password fields in the returned
data. To get all the data, use the L<backend|/yancy.backend> helper to
access the backend methods directly.

=head2 yancy.get

    my $item = $c->yancy->get( $collection, $id );

Get an item from the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to get. See L<Yancy::Backend/get>.

This helper will filter out password values in the returned data. To get
all the data, use the L<backend|/yancy.backend> helper to access the
backend directly.

=head2 yancy.set

    $c->yancy->set( $collection, $id, $item_data, %opt );

Update an item in the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to update. C<$item_data> is a hash of data
to update. See L<Yancy::Backend/set>. C<%opt> is a list of options with
the following keys:

=over

=item * properties - An arrayref of properties to validate, for partial updates

=back

This helper will validate the data against the configuration and run any
filters as needed. If validation fails, this helper will throw an
exception with an array reference of L<JSON::Validator::Error> objects.
See L<the validate helper|/yancy.validate> and L<the filter apply
helper|/yancy.filter.apply>. To bypass filters and validation, use the
backend object directly via L<the backend helper|/yancy.backend>.

    # A route to update a comment
    put '/comment/:id' => sub {
        eval { $c->yancy->set( "comment", $c->stash( 'id' ), $c->req->json ) };
        if ( $@ ) {
            return $c->render( status => 400, errors => $@ );
        }
        return $c->render( status => 200, text => 'Success!' );
    };

=head2 yancy.create

    my $item = $c->yancy->create( $collection, $item_data );

Create a new item. C<$collection> is the collection name. C<$item_data>
is a hash of data for the new item. See L<Yancy::Backend/create>.

This helper will validate the data against the configuration and run any
filters as needed. If validation fails, this helper will throw an
exception with an array reference of L<JSON::Validator::Error> objects.
See L<the validate helper|/yancy.validate> and L<the filter apply
helper|/yancy.filter.apply>. To bypass filters and validation, use the
backend object directly via L<the backend helper|/yancy.backend>.

    # A route to create a comment
    post '/comment' => sub {
        eval { $c->yancy->create( "comment", $c->req->json ) };
        if ( $@ ) {
            return $c->render( status => 400, errors => $@ );
        }
        return $c->render( status => 200, text => 'Success!' );
    };

=head2 yancy.delete

    $c->yancy->delete( $collection, $id );

Delete an item from the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to delete. See L<Yancy::Backend/delete>.

=head2 yancy.validate

    my @errors = $c->yancy->validate( $collection, $item, %opt );

Validate the given C<$item> data against the configuration for the
C<$collection>. If there are any errors, they are returned as an array
of L<JSON::Validator::Error> objects. C<%opt> is a list of options with
the following keys:

=over

=item * properties - An arrayref of properties to validate, for partial updates

=back

See L<JSON::Validator/validate> for more details.

=head2 yancy.filter.add

    my $filter_sub = sub { my ( $field_name, $field_value, $field_conf ) = @_; ... }
    $c->yancy->filter->add( $name => $filter_sub );

Create a new filter. C<$name> is the name of the filter to give in the
field's configuration. C<$subref> is a subroutine reference that accepts
three arguments:

=over

=item * $name - The name of the collection/field being filtered

=item * $value - The value to filter, either the entire item, or a single field

=item * $conf - The configuration for the collection/field

=back

For example, here is a filter that will run a password through a one-way hash
digest:

    use Digest;
    my $digest = sub {
        my ( $field_name, $field_value, $field_conf ) = @_;
        my $type = $field_conf->{ 'x-digest' }{ type };
        Digest->new( $type )->add( $field_value )->b64digest;
    };
    $c->yancy->filter->add( 'digest' => $digest );

And you configure this on a field using C<< x-filter >> and C<< x-digest >>:

    # mysite.conf
    {
        collections => {
            users => {
                properties => {
                    username => { type => 'string' },
                    password => {
                        type => 'string',
                        format => 'password',
                        'x-filter' => [ 'digest' ], # The name of the filter
                        'x-digest' => {             # Filter configuration
                            type => 'SHA-1',
                        },
                    },
                },
            },
        },
    }

Collections can also have filters. A collection filter will get the
entire hash reference as its value. For example, here's a filter that
updates the C<last_updated> field with the current time:

    $c->yancy->filter->add( 'timestamp' => sub {
        my ( $coll_name, $item, $coll_conf ) = @_;
        $item->{last_updated} = time;
        return $item;
    } );

And you configure this on the collection using C<< x-filter >>:

    # mysite.conf
    {
        collections => {
            people => {
                'x-filter' => [ 'timestamp' ],
                properties => {
                    name => { type => 'string' },
                    address => { type => 'string' },
                    last_updated => { type => 'datetime' },
                },
            },
        },
    }

=head2 yancy.filter.apply

    my $filtered_data = $c->yancy->filter->apply( $collection, $item_data );

Run the configured filters on the given C<$item_data>. C<$collection> is
a collection name. Returns the hash of C<$filtered_data>.

The property-level filters will run before any collection-level filter,
so that collection-level filters can take advantage of any values set by
the inner filters.

=head2 yancy.schema

    my $schema = $c->yancy->schema( $name );
    $c->yancy->schema( $name => $schema );
    my $schemas = $c->yancy->schema;

Get or set the JSON schema for the given collection C<$name>. If no
collection name is given, returns a hashref of all the collections.

=head2 yancy.openapi

    my $openapi = $c->yancy->openapi;

Get the L<Mojolicious::Plugin::OpenAPI> object containing the OpenAPI
interface for this Yancy API.

=head1 TEMPLATES

This plugin uses the following templates. To override these templates
with your own theme, provide a template with the same name. Remember to
add your template paths to the beginning of the list of paths to be sure
your templates are found first:

    # Mojolicious::Lite
    unshift @{ app->renderer->paths }, 'template/directory';
    unshift @{ app->renderer->classes }, __PACKAGE__;

    # Mojolicious
    sub startup {
        my ( $app ) = @_;
        unshift @{ $app->renderer->paths }, 'template/directory';
        unshift @{ $app->renderer->classes }, __PACKAGE__;
    }

=over

=item layouts/yancy.html.ep

This layout template surrounds all other Yancy templates.  Like all
Mojolicious layout templates, a replacement should use the C<content>
helper to display the page content. Additionally, a replacement should
use C<< content_for 'head' >> to add content to the C<head> element.

=item yancy/index.html.ep

This is the main Yancy web application. You should not override this. If
you need to, consider filing a bug report or feature request.

=back

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy;
use Mojo::JSON qw( true false );
use Mojo::File qw( path );
use Mojo::JSON qw( decode_json );
use Mojo::Loader qw( load_class );
use Mojo::Util qw( url_escape );
use Sys::Hostname qw( hostname );
use Yancy::Util qw( load_backend curry );
use JSON::Validator::OpenAPI::Mojolicious;

has _filters => sub { {} };

sub register {
    my ( $self, $app, $config ) = @_;
    my $route = $config->{route} // $app->routes->any( '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );
    $config->{api_controller} //= 'Yancy::API';
    $config->{openapi} = _ensure_json_data( $app, $config->{openapi} );

    # Resources and templates
    my $share = path( __FILE__ )->sibling( 'Yancy' )->child( 'resources' );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths }, $share->child( 'templates' )->to_string;
    push @{$app->routes->namespaces}, 'Yancy::Controller';

    # Helpers
    $app->helper( 'yancy.config' => sub { return $config } );
    $app->helper( 'yancy.route' => sub { return $route } );
    $app->helper( 'yancy.backend' => sub {
        state $backend = load_backend( $config->{backend}, $config->{collections} || $config->{openapi}{definitions} );
    } );

    $app->helper( 'yancy.plugin' => \&_helper_plugin );
    $app->helper( 'yancy.schema' => \&_helper_schema );
    $app->helper( 'yancy.list' => \&_helper_list );
    $app->helper( 'yancy.get' => \&_helper_get );
    $app->helper( 'yancy.delete' => \&_helper_delete );
    $app->helper( 'yancy.set' => \&_helper_set );
    $app->helper( 'yancy.create' => \&_helper_create );
    $app->helper( 'yancy.validate' => \&_helper_validate );

    for my $name ( keys %{ $config->{filters} } ) {
        $self->_helper_filter_add( undef, $name, $config->{filters}{$name} );
    }
    $app->helper( 'yancy.filter.add' => curry( \&_helper_filter_add, $self ) );
    $app->helper( 'yancy.filter.apply' => curry( \&_helper_filter_apply, $self ) );

    # Routes
    $route->get( '/' )->name( 'yancy.index' )
        ->to(
            template => 'yancy/index',
            controller => $config->{api_controller},
            action => 'index',
        );

    die "Cannot pass both openapi AND (collections or read_schema)"
        if $config->{openapi}
        and ( $config->{collections} or $config->{read_schema} );

    my $spec;
    if ( $config->{openapi} ) {
        $spec = $config->{openapi};
    }
    else {
        # Merge configuration
        if ( $config->{read_schema} ) {
            my $schema = $app->yancy->backend->read_schema;
            for my $c ( keys %$schema ) {
                _merge_schema( $config->{collections}{ $c } ||= {}, $schema->{ $c } );
            }
            # ; say 'Merged Config';
            # ; use Data::Dumper;
            # ; say Dumper $config;
        }
        # read_schema on collections
        for my $schema_name ( keys %{ $config->{collections} } ) {
            my $schema = $config->{collections}{ $schema_name };
            if ( delete $schema->{read_schema} ) {
                _merge_schema( $schema, $app->yancy->backend->read_schema( $schema_name ) );
            }
        }

        # Sanity check for the schema.
        for my $schema_name ( keys %{ $config->{collections} } ) {
            my $schema = $config->{collections}{ $schema_name };
            next if $schema->{ 'x-ignore' }; # XXX Should we just delete x-ignore collections?
            my $props = $schema->{ properties };
            my $id_field = $schema->{ 'x-id-field' } // 'id';
            if ( !$props->{ $id_field } ) {
                die sprintf "ID field missing in properties for collection '%s', field '%s'."
                    . " Add x-id-field to configure the correct ID field name, or"
                    . " add x-ignore to ignore this collection.",
                        $schema_name, $id_field;
            }
        }

        # Add OpenAPI spec
        $spec = $self->_openapi_spec_from_schema( $config );
    }
    $self->_openapi_spec_add_mojo( $spec, $config );

    my $openapi = $app->plugin( OpenAPI => {
        route => $route->any( '/api' )->name( 'yancy.api' ),
        spec => $spec,
        default_response_name => '_Error',
    } );
    $app->helper( 'yancy.openapi' => sub { $openapi } );

    # Add supported formats to silence warnings from JSON::Validator
    my $formats = $openapi->validator->formats;
    $formats->{ password } = sub { undef };
    $formats->{ markdown } = sub { undef };
    $formats->{ tel } = sub { undef };
}

# if false or a ref, just returns same
# if non-ref, treat as JSON-containing file, load and decode
sub _ensure_json_data {
    my ( $app, $data ) = @_;
    return $data if !$data or ref $data;
    # assume a file in JSON format: load and parse it
    decode_json $app->home->child( $data )->slurp;
}

sub _openapi_find_collection_name {
    my ( $self, $path, $pathspec ) = @_;
    return $pathspec->{'x-collection'} if $pathspec->{'x-collection'};
    my $collection;
    for my $method ( grep !/^(parameters$|x-)/, keys %{ $pathspec } ) {
        my $op_spec = $pathspec->{ $method };
        my $schema;
        if ( $method eq 'get' ) {
            # d is in case only has "default" response
            my ($response) = grep /^[2d]/, sort keys %{ $op_spec->{responses} };
            my $response_spec = $op_spec->{responses}{$response};
            next unless $schema = $response_spec->{schema};
        } elsif ( $method =~ /^(put|post)$/ ) {
            my @body_params = grep 'body' eq ($_->{in} // ''),
                @{ $op_spec->{parameters} || [] },
                @{ $pathspec->{parameters} || [] },
                ;
            die "No more than 1 'body' parameter allowed" if @body_params > 1;
            next unless $schema = $body_params[0]->{schema};
        }
        next unless my $this_ref =
            $schema->{'$ref'} ||
            ( $schema->{items} && $schema->{items}{'$ref'} ) ||
            ( $schema->{properties} && $schema->{properties}{items} && $schema->{properties}{items}{'$ref'} );
        next unless $this_ref =~ s:^#/definitions/::;
        die "$method '$path' = $this_ref but also '$collection'"
            if $this_ref and $collection and $this_ref ne $collection;
        $collection = $this_ref;
    }
    if ( !$collection ) {
        ($collection) = $path =~ m#^/([^/]+)#;
        die "No collection found in '$path'" if !$collection;
    }
    $collection;
}

# mutates $spec
sub _openapi_spec_add_mojo {
    my ( $self, $spec, $config ) = @_;
    for my $path ( keys %{ $spec->{paths} } ) {
        my $pathspec = $spec->{paths}{ $path };
        my $collection = $self->_openapi_find_collection_name( $path, $pathspec );
        die "Path '$path' had non-existent collection '$collection'"
            if !$spec->{definitions}{$collection};
        for my $method ( grep !/^(parameters$|x-)/, keys %{ $pathspec } ) {
            my $op_spec = $pathspec->{ $method };
            my $mojo = $self->_openapi_spec_infer_mojo( $path, $pathspec, $method, $op_spec );
            $mojo->{controller} = $config->{api_controller};
            $mojo->{collection} = $collection;
            $op_spec->{ 'x-mojo-to' } = $mojo;
        }
    }
}

# for a given OpenAPI operation, figures out right values for 'x-mojo-to'
# to hook it up to the correct CRUD operation
sub _openapi_spec_infer_mojo {
    my ( $self, $path, $pathspec, $method, $op_spec ) = @_;
    my @path_params = grep 'path' eq ($_->{in} // ''),
        @{ $pathspec->{parameters} || [] },
        @{ $op_spec->{parameters} || [] },
        ;
    my ($id_field) = grep defined,
        (map $_->{'x-id-field'}, $op_spec, $pathspec),
        (@path_params && $path_params[-1]{name});
    if ( $method eq 'get' ) {
        # heuristic: is per-item if have a param in path
        if ( $id_field ) {
            # per-item - GET = "read"
            return {
                action => 'get_item',
                id_field => $id_field,
            };
        }
        else {
            # per-collection - GET = "list"
            return {
                action => 'list_items',
            };
        }
    } elsif ( $method eq 'post' ) {
        return {
            action => 'add_item',
        };
    } elsif ( $method eq 'put' ) {
        die "'$method' $path needs id_field" if !$id_field;
        return {
            action => 'set_item',
            id_field => $id_field,
        };
    } elsif ( $method eq 'delete' ) {
        die "'$method' $path needs id_field" if !$id_field;
        return {
            action => 'delete_item',
            id_field => $id_field,
        };
    }
    else {
        die "Unknown method '$method'";
    }
}

sub _openapi_spec_from_schema {
    my ( $self, $config ) = @_;
    my ( %definitions, %paths );
    my %parameters = (
        '$limit' => {
            name => '$limit',
            type => 'integer',
            in => 'query',
            description => 'The number of items to return',
        },
        '$offset' => {
            name => '$offset',
            type => 'integer',
            in => 'query',
            description => 'The index (0-based) to start returning items',
        },
        '$order_by' => {
            name => '$order_by',
            type => 'string',
            in => 'query',
            pattern => '^(?:asc|desc):[^:,]+$',
            description => 'How to sort the list. A string containing one of "asc" (to sort in ascending order) or "desc" (to sort in descending order), followed by a ":", followed by the field name to sort by.',
        },
    );
    for my $name ( keys %{ $config->{collections} } ) {
        # Set some defaults so users don't have to type as much
        my $collection = $config->{collections}{ $name };
        next if $collection->{ 'x-ignore' };
        $collection->{ type } //= 'object';
        my $id_field = $collection->{ 'x-id-field' } // 'id';
        my %props = %{ $collection->{ properties } };

        $definitions{ $name } = $collection;

        for my $prop ( keys %props ) {
            $props{ $prop }{ type } ||= 'string';
        }

        $paths{ '/' . $name } = {
            get => {
                parameters => [
                    { '$ref' => '#/parameters/%24limit' },
                    { '$ref' => '#/parameters/%24offset' },
                    { '$ref' => '#/parameters/%24order_by' },
                    map {; {
                        name => $_,
                        in => 'query',
                        type => ref $props{ $_ }{type} eq 'ARRAY'
                                ? $props{ $_ }{type}[0] : $props{ $_ }{type},
                        description => "Filter the list by the $_ field. By default, looks for rows containing the value anywhere in the column. Use '*' anywhere in the value to anchor the match.",
                    } } keys %props,
                ],
                responses => {
                    200 => {
                        description => 'List of items',
                        schema => {
                            type => 'object',
                            required => [qw( items total )],
                            properties => {
                                total => {
                                    type => 'integer',
                                    description => 'The total number of items available',
                                },
                                items => {
                                    type => 'array',
                                    description => 'This page of items',
                                    items => { '$ref' => "#/definitions/" . url_escape $name },
                                },
                            },
                        },
                    },
                    default => {
                        description => 'Unexpected error',
                        schema => { '$ref' => '#/definitions/_Error' },
                    },
                },
            },
            post => {
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/" . url_escape $name },
                    },
                ],
                responses => {
                    201 => {
                        description => "Entry was created",
                        schema => {
                            '$ref' => sprintf "#/definitions/%s/properties/%s",
                                      map { url_escape $_ } $name, $id_field,
                        },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => "#/definitions/_Error" },
                    },
                },
            },
        };

        $paths{ sprintf '/%s/{%s}', $name, $id_field } = {
            parameters => [
                {
                    name => $id_field,
                    in => 'path',
                    description => 'The id of the item',
                    required => true,
                    type => 'string',
                    'x-mojo-placeholder' => '*',
                },
            ],

            get => {
                description => "Fetch a single item",
                responses => {
                    200 => {
                        description => "Item details",
                        schema => { '$ref' => "#/definitions/" . url_escape $name },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => '#/definitions/_Error' },
                    }
                }
            },

            put => {
                description => "Update a single item",
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/" . url_escape $name },
                    }
                ],
                responses => {
                    200 => {
                        description => "Item was updated",
                        schema => { '$ref' => "#/definitions/" . url_escape $name },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => "#/definitions/_Error" },
                    }
                }
            },

            delete => {
                description => "Delete a single item",
                responses => {
                    204 => {
                        description => "Item was deleted",
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => '#/definitions/_Error' },
                    },
                },
            },
        };
    }

    return {
        info => $config->{info} || { title => 'Yancy', version => 1 },
        swagger => '2.0',
        host => $config->{host} // hostname(),
        basePath => '/api',
        schemes => [qw( http )],
        consumes => [qw( application/json )],
        produces => [qw( application/json )],
        definitions => {
            _Error => {
                title => 'OpenAPI Error Object',
                type => 'object',
                properties => {
                    errors => {
                        type => "array",
                        items => {
                            required => [qw( message )],
                            properties => {
                                message => {
                                    type => "string",
                                    description => "Human readable description of the error",
                                },
                                path => {
                                    type => "string",
                                    description => "JSON pointer to the input data where the error occur"
                                }
                            }
                        }
                    }
                }
            },
            %definitions,
        },
        paths => \%paths,
        parameters => \%parameters,
    };
}

#=sub _build_validator
#
#   my $validator = _build_validator( $schema );
#
# Build a JSON::Validator object for the given schema, adding all the
# necessary attributes.
#
sub _build_validator {
    my ( $schema ) = @_;
    my $v = JSON::Validator::OpenAPI::Mojolicious->new(
        # This fixes HTML forms submitting the string "20" not being
        # detected as a number, or the number 1 not being detected as
        # a boolean
        coerce => { booleans => 1, numbers => 1 },
    );
    my $formats = $v->formats;
    $formats->{ password } = sub { undef };
    $formats->{ markdown } = sub { undef };
    $formats->{ tel } = sub { undef };
    $v->schema( $schema );
    return $v;
}

sub _helper_plugin {
    my ( $c, $name, @args ) = @_;
    my $class = 'Yancy::Plugin::' . $name;
    if ( my $e = load_class( $class ) ) {
        die ref $e ? "Could not load class $class: $e" : "Could not find class $class";
    }
    my $plugin = $class->new;
    $plugin->register( $c->app, @args );
}

sub _helper_schema {
    my ( $c, $name, $schema ) = @_;
    if ( !$name ) {
        return $c->yancy->config->{collections};
    }
    if ( $schema ) {
        $c->yancy->config->{collections}{ $name } = $schema;
        return;
    }
    if (!  $c->yancy->config->{collections}) {
        return;
    }
    return $c->yancy->config->{collections}{ $name };
}

sub _helper_list {
    my ( $c, $coll_name, @args ) = @_;
    my @items = @{ $c->yancy->backend->list( $coll_name, @args )->{items} };
    my $coll = $c->yancy->schema( $coll_name );
    for my $prop_name ( keys %{ $coll->{properties} } ) {
        my $prop = $coll->{properties}{ $prop_name };
        if ( $prop->{format} && $prop->{format} eq 'password' ) {
            delete $_->{ $prop_name } for @items;
        }
    }
    return @items;
}

sub _helper_get {
    my ( $c, $coll_name, $id, @args ) = @_;
    my $item = $c->yancy->backend->get( $coll_name, $id, @args );
    my $coll = $c->yancy->schema( $coll_name );
    for my $prop_name ( keys %{ $coll->{properties} } ) {
        my $prop = $coll->{properties}{ $prop_name };
        if ( $prop->{format} && $prop->{format} eq 'password' ) {
            delete $item->{ $prop_name };
        }
    }
    return $item;
}

sub _helper_delete {
    my ( $c, @args ) = @_;
    return $c->yancy->backend->delete( @args );
}

sub _helper_set {
    my ( $c, $coll, $id, $item, %opt ) = @_;
    my %validate_opt =
        map { $_ => $opt{ $_ } }
        grep { exists $opt{ $_ } }
        qw( properties );
    if ( my @errors = $c->yancy->validate( $coll, $item, %validate_opt ) ) {
        $c->app->log->error(
            sprintf 'Error validating item with ID "%s" in collection "%s": %s',
            $id, $coll,
            join ', ', map { sprintf '%s (%s)', $_->{message}, $_->{path} // '/' } @errors
        );
        die \@errors;
    }
    $item = $c->yancy->filter->apply( $coll, $item );
    my $ret = eval { $c->yancy->backend->set( $coll, $id, $item ) };
    if ( $@ ) {
        $c->app->log->error(
            sprintf 'Error setting item with ID "%s" in collection "%s": %s',
            $id, $coll, $@,
        );
        die $@;
    }
    return $ret;
}

sub _helper_create {
    my ( $c, $coll, $item ) = @_;
    if ( my @errors = $c->yancy->validate( $coll, $item ) ) {
        $c->app->log->error(
            sprintf 'Error validating new item in collection "%s": %s',
            $coll,
            join ', ', map { sprintf '%s (%s)', $_->{message}, $_->{path} // '/' } @errors
        );
        die \@errors;
    }
    $item = $c->yancy->filter->apply( $coll, $item );
    my $ret = eval { $c->yancy->backend->create( $coll, $item ) };
    if ( $@ ) {
        $c->app->log->error(
            sprintf 'Error creating item in collection "%s": %s',
            $coll, $@,
        );
        die $@;
    }
    return $ret;
}

sub _helper_validate {
    my ( $c, $coll, $item, %opt ) = @_;
    state $validator = {};
    my $schema = $c->yancy->schema( $coll );
    my $v = $validator->{ $coll } ||= _build_validator( $schema );

    my @args;
    if ( $opt{ properties } ) {
        # Only validate these properties
        @args = (
            {
                type => 'object',
                required => [
                    grep { my $f = $_; grep { $_ eq $f } @{ $schema->{required} || [] } }
                    @{ $opt{ properties } }
                ],
                properties => {
                    map { $_ => $schema->{properties}{$_} }
                    grep { exists $schema->{properties}{$_} }
                    @{ $opt{ properties } }
                },
                additionalProperties => 0, # Disallow any other properties
            }
        );
        $schema = $args[0];
    }

    # Pre-filter booleans
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };
        my $is_boolean = ref $prop->{type} eq 'ARRAY'
            ? ( grep { $_ eq 'boolean' } @{ $prop->{type} } )
            : ( $prop->{type} eq 'boolean' )
            ;
        if ( $is_boolean && defined $item->{ $prop_name } ) {
            my $value = $item->{ $prop_name };
            if ( $value eq 'false' or !$value ) {
                $value = false;
            } else {
                $value = true;
            }
            $item->{ $prop_name } = $value;
        }
    }

    my @errors = $v->validate_input( $item, @args );
    return @errors;
}

sub _helper_filter_apply {
    my ( $self, $c, $coll_name, $item ) = @_;
    my $coll = $c->yancy->schema( $coll_name );
    my $filters = $self->_filters;
    for my $key ( keys %{ $coll->{properties} } ) {
        next unless my $prop_filters = $coll->{properties}{ $key }{ 'x-filter' };
        for my $filter ( @{ $prop_filters } ) {
            my $sub = $filters->{ $filter };
            die "Unknown filter: $filter (collection: $coll_name, field: $key)"
                unless $sub;
            $item->{ $key } = $sub->(
                $key, $item->{ $key }, $coll->{properties}{ $key }
            );
        }
    }
    if ( my $coll_filters = $coll->{'x-filter'} ) {
        for my $filter ( @{ $coll_filters } ) {
            my $sub = $filters->{ $filter };
            die "Unknown filter: $filter (collection: $coll_name)"
                unless $sub;
            $item = $sub->( $coll_name, $item, $coll );
        }
    }
    return $item;
}

sub _helper_filter_add {
    my ( $self, $c, $name, $sub ) = @_;
    $self->_filters->{ $name } = $sub;
}

# _merge_schema( $keep, $merge );
#
# Merge the given $merge schema into the given $keep schema. $keep is
# modified in-place (but also returned)
sub _merge_schema {
    my ( $keep, $merge ) = @_;
    my $keep_props = $keep->{properties} ||= {};
    my $merge_props = delete $merge->{properties};
    for my $k ( keys %$merge ) {
        $keep->{ $k } ||= $merge->{ $k };
    }
    for my $p ( keys %{ $merge_props } ) {
        my $keep_prop = $keep_props->{ $p } ||= {};
        my $merge_prop = $merge_props->{ $p };
        for my $k ( keys %$merge_prop ) {
            $keep_prop->{ $k } ||= $merge_prop->{ $k };
        }
    }
    return $keep;
}
1;
