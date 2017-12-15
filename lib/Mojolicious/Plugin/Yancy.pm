package Mojolicious::Plugin::Yancy;
our $VERSION = '0.007';
# ABSTRACT: Embed a simple admin CMS into your Mojolicious application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://postgres@/mydb',
        collections => { ... },
    };

    ## With custom auth routine
    use Mojo::Base 'Mojolicious';
    sub startup( $app ) {
        my $auth_route = $app->routes->under( '/yancy', sub( $c ) {
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
L<Yancy/CONFIGURATION>.

Additional configuration keys accepted by the plugin are:

=over

=item route

A base route to add Yancy to. This allows you to customize the URL
and add authentication or authorization. Defaults to allowing access
to the Yancy web application under C</yancy>, and the REST API under
C</yancy/api>.

=item filters

A hash of C<< name => subref >> pairs of filters to make available.
See L</yancy.filter.add> for how to create a filter subroutine.

=back

=head1 HELPERS

This plugin adds some helpers for use in routes, templates, and plugins.

=head2 yancy.backend

    my $be = $c->yancy->backend;

Get the currently-configured Yancy backend object.

=head2 yancy.route

Get the root route where the Yancy CMS will appear. Useful for adding
checks:

    my $route = $c->yancy->route;
    my $auth_route = $route->parent->under( sub {
        # ... Check auth
        return 1;
    } );
    $auth_route->add_child( $route );

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

=item * limit - The number of rows to return

=item * offset - The number of rows to skip before returning rows

=back

See your backend documentation for more information about the C<list>
method arguments. This helper only returns the list of items, not the
total count of items or any other value.

=head2 yancy.get

    my $item = $c->yancy->get( $collection, $id );

Get an item from the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to get.

=head2 yancy.set

    $c->yancy->set( $collection, $id, $item_data );

Update an item in the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to update. C<$item_data> is a hash of data
to update.

=head2 yancy.create

    my $item = $c->yancy->create( $collection, $item_data );

Create a new item. C<$collection> is the collection name. C<$item_data>
is a hash of data for the new item.

=head2 yancy.delete

    $c->yancy->delete( $collection, $id );

Delete an item from the backend. C<$collection> is the collection name.
C<$id> is the ID of the item to delete.

=head2 yancy.filter.add

    my $filter_sub = sub( $field_name, $field_value, $field_conf ) { ... }
    $c->yancy->filter->add( $name => $filter_sub );

Create a new filter. C<$name> is the name of the filter to give in the
field's configuration. C<$subref> is a subroutine reference that accepts
three arguments:

=over

=item * $field_name - The name of the field being filtered

=item * $field_value - The value to filter

=item * $field_conf - The full configuration for the field

=back

For example, here is a filter that will run a password through a one-way hash
digest:

    use Digest;
    my $digest = sub( $field_name, $field_value, $field_conf ) {
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

See L<Yancy/CONFIGURATION> for more information on how to add filters to
fields.

=head2 yancy.filter.apply

    my $filtered_data = $c->yancy->filter->apply( $collection, $item_data );

Run the configured filters on the given C<$item_data>. C<$collection> is
a collection name. Returns the hash of C<$filtered_data>.

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
use v5.24;
use experimental qw( signatures postderef );
use Mojo::JSON qw( true false );
use File::Share qw( dist_dir );
use Mojo::File qw( path );
use Module::Runtime qw( use_module );
use Sys::Hostname qw( hostname );

=method register

Set up the plugin. Called automatically by Mojolicious.

=cut

sub register( $self, $app, $config ) {
    my $route = $config->{route} // $app->routes->any( '/yancy' );

    # Resources and templates
    my $share = path( dist_dir( 'Yancy' ) );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths}, $share->child( 'templates' )->to_string;
    push @{$app->routes->namespaces}, 'Yancy::Controller';

    # Helpers
    $app->helper( 'yancy.route' => sub { return $route } );
    $app->helper( 'yancy.backend' => sub {
        state $backend;
        if ( !$backend ) {
            my ( $type ) = $config->{backend} =~ m{^([^:]+)};
            my $class = 'Yancy::Backend::' . ucfirst $type;
            use_module( $class );
            $backend = $class->new( $config->{backend}, $config->{collections} );
        }
        return $backend;
    } );
    $app->helper( 'yancy.list' => sub {
        my ( $c, @args ) = @_;
        return @{ $c->yancy->backend->list( @args )->{rows} };
    } );
    for my $be_method ( qw( get set delete create ) ) {
        $app->helper( 'yancy.' . $be_method => sub {
            my ( $c, @args ) = @_;
            return $c->yancy->backend->$be_method( @args );
        } );
    }

    $config->{filters} ||= {};
    $app->helper( 'yancy.filter.add' => sub( $c, $name, $sub ) {
        $config->{filters}{ $name } = $sub;
    } );
    $app->helper( 'yancy.filter.apply' => sub( $c, $coll_name, $item ) {
        my $coll = $config->{collections}{$coll_name};
        for my $key ( keys $coll->{properties}->%* ) {
            next unless $coll->{properties}{ $key }{ 'x-filter' };
            for my $filter ( $coll->{properties}{ $key }{ 'x-filter' }->@* ) {
                die "Unknown filter: $filter (collection: $coll_name, field: $key)"
                    unless $config->{filters}{ $filter };
                $item->{ $key } = $config->{filters}{ $filter }->(
                    $key, $item->{ $key }, $coll->{properties}{ $key }
                );
            }
        }
        return $item;
    } );

    # Routes
    $route->get( '/' )->name( 'yancy.index' )->to( 'yancy#index' );

    # Add OpenAPI spec
    $app->plugin( OpenAPI => {
        route => $route->any( '/api' )->name( 'yancy.api' ),
        spec => $self->_build_openapi_spec( $config ),
    } );

}

sub _build_openapi_spec( $self, $config ) {
    my ( %definitions, %paths );
    for my $name ( keys $config->{collections}->%* ) {
        # Set some defaults so users don't have to type as much
        my $collection = $config->{collections}{ $name };
        $collection->{ type } //= 'object';
        my $id_field = $collection->{ 'x-id-field' } // 'id';

        $definitions{ $name . 'Item' } = $collection;
        $definitions{ $name . 'Array' } = {
            type => 'array',
            items => { '$ref' => "#/definitions/${name}Item" },
        };

        $paths{ '/' . $name } = {
            get => {
                'x-mojo-to' => {
                    controller => 'yancy',
                    action => 'list_items',
                    collection => $name,
                },
                parameters => [
                    {
                        name => 'limit',
                        type => 'integer',
                        in => 'query',
                        description => 'The number of items to return',
                    },
                    {
                        name => 'offset',
                        type => 'integer',
                        in => 'query',
                        description => 'The index (0-based) to start returning items',
                    },
                    {
                        name => 'order_by',
                        type => 'string',
                        in => 'query',
                        pattern => '^(?:asc|desc):[^:,]+$',
                    },
                ],
                responses => {
                    200 => {
                        description => 'List of items',
                        schema => {
                            type => 'object',
                            required => [qw( rows total )],
                            properties => {
                                total => {
                                    type => 'integer',
                                    description => 'The total number of items available',
                                },
                                rows => {
                                    type => 'array',
                                    description => 'This page of items',
                                    items => { '$ref' => "#/definitions/${name}Item" },
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
                'x-mojo-to' => {
                    controller => 'yancy',
                    action => 'add_item',
                    collection => $name,
                },
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/${name}Item" },
                    },
                ],
                responses => {
                    201 => {
                        description => "Entry was created",
                        schema => { '$ref' => "#/definitions/${name}Item" },
                    },
                    400 => {
                        description => "New entry contains errors",
                        schema => { '$ref' => "#/definitions/_Error" },
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
                },
            ],

            get => {
                'x-mojo-to' => {
                    controller => 'yancy',
                    action => 'get_item',
                    collection => $name,
                    id_field => $id_field,
                },
                description => "Fetch a single item",
                responses => {
                    200 => {
                        description => "Item details",
                        schema => { '$ref' => "#/definitions/${name}Item" },
                    },
                    404 => {
                        description => "The item was not found",
                        schema => { '$ref' => '#/definitions/_Error' },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => '#/definitions/_Error' },
                    }
                }
            },

            put => {
                'x-mojo-to' => {
                    controller => 'yancy',
                    action => 'set_item',
                    collection => $name,
                    id_field => $id_field,
                },
                description => "Update a single item",
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/${name}Item" },
                    }
                ],
                responses => {
                    200 => {
                        description => "Item was updated",
                        schema => { '$ref' => "#/definitions/${name}Item" },
                    },
                    404 => {
                        description => "The item was not found",
                        schema => { '$ref' => "#/definitions/_Error" },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => "#/definitions/_Error" },
                    }
                }
            },

            delete => {
                'x-mojo-to' => {
                    controller => 'yancy',
                    action => 'delete_item',
                    collection => $name,
                    id_field => $id_field,
                },
                description => "Delete a single item",
                responses => {
                    204 => {
                        description => "Item was deleted",
                    },
                    404 => {
                        description => "The item was not found",
                        schema => { '$ref' => '#/definitions/_Error' },
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
    };
}

1;
