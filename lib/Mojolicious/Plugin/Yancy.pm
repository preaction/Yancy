package Mojolicious::Plugin::Yancy;
our $VERSION = '0.001';
# ABSTRACT: Embed a simple admin CMS into your Mojolicious application

=head1 SYNOPSIS

=head1 DESCRIPTION

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

XXX: Add config

=cut

sub register( $self, $app, $config ) {
    my $route = $config->{route} // $app->routes->any( '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );

    # Resources and templates
    my $share = path( dist_dir( 'Yancy' ) );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths}, $share->child( 'templates' )->to_string;

    # Helpers
    $app->helper( backend => sub {
        state $backend;
        if ( !$backend ) {
            my ( $type ) = $config->{backend} =~ m{^([^:]+)};
            my $class = 'Yancy::Backend::' . ucfirst $type;
            use_module( $class );
            $backend = $class->new( $config->{backend} );
        }
        return $backend;
    } );

    # Routes
    $route->get( '/:collection' )->name( 'list_items' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 200,
                openapi => $c->backend->list( $c->stash( 'collection' ) ),
            );
        },
    );

    $route->post( '/:collection' )->name( 'add_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 201,
                openapi => $c->backend->create( $c->stash( 'collection' ), $c->req->json ),
            );
        },
    );

    $route->get( '/:collection/:id' )->name( 'get_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 200,
                openapi => $c->backend->get( $c->stash( 'collection' ), $c->stash( 'id' ) ),
            );
        },
    );

    $route->put( '/:collection/:id' )->name( 'set_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            $c->backend->set( $c->stash( 'collection' ), $c->stash( 'id' ), $c->req->json );
            return $c->render(
                status => 200,
                openapi => $c->backend->get( $c->stash( 'collection' ), $c->stash( 'id' ) ),
            );
        },
    );

    $route->delete( '/:collection/:id' )->name( 'delete_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            $c->backend->delete( $c->stash( 'collection' ), $c->stash( 'id' ) );
            return $c->rendered( 204 );
        },
    );

    $route->get( '/' )->name( 'index' )->to( '#index' );

    # Add OpenAPI spec
    $app->plugin( OpenAPI => { spec => $self->_build_openapi_spec( $config ) } );
}

sub _build_openapi_spec( $self, $config ) {
    my ( %definitions, %paths );
    for my $name ( keys $config->{collections}->%* ) {
        # Set some defaults so users don't have to type as much
        $config->{ collections }{ $name }{ type } //= 'object';

        $definitions{ $name . 'Item' } = $config->{ collections }{ $name };
        $definitions{ $name . 'Array' } = {
            type => 'array',
            items => { '$ref' => "#/definitions/${name}Item" },
        };

        $paths{ '/' . $name } = {
            get => {
                'x-mojo-name' => 'list_items',
                responses => {
                    200 => {
                        description => 'List of items',
                        schema => { '$ref' => "#/definitions/${name}Array" },
                    },
                    default => {
                        description => 'Unexpected error',
                        schema => { '$ref' => '#/definitions/_Error' },
                    },
                },
            },
            post => {
                'x-mojo-name' => 'add_item',
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

        $paths{ '/' . $name . '/{id}' } = {
            parameters => [
                {
                    name => 'id',
                    in => 'path',
                    description => 'The id of the item',
                    required => true,
                    type => 'string',
                },
            ],

            get => {
                'x-mojo-name' => 'get_item',
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
                'x-mojo-name' => 'set_item',
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
                'x-mojo-name' => 'delete_item',
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
