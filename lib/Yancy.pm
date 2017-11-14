package Yancy;
our $VERSION = '0.001';
# ABSTRACT: Write a sentence about what it does

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use v5.24;
use Mojo::Base 'Mojolicious';
use experimental qw( signatures postderef );
use Mojo::JSON qw( true false );
use Sys::Hostname qw( hostname );
use Module::Runtime qw( use_module );

sub startup( $app ) {

    $app->plugin( Config => { default => { } } );

    $app->helper( backend => sub {
        state $backend;
        if ( !$backend ) {
            my ( $type ) = $app->config->{backend} =~ m{^([^:]+)};
            my $class = 'Yancy::Backend::' . ucfirst $type;
            use_module( $class );
            $backend = $class->new( $app->config->{backend} );
        }
        return $backend;
    } );

    my ( %definitions, %paths );
    my %config = $app->config->%*;
    for my $name ( keys $config{collections}->%* ) {
        $definitions{ $name . 'Item' } = $config{ collections }{ $name };
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
                    204 => {
                        description => "Item was updated",
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

    $app->routes->get( '/:collection' )->name( 'list_items' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 200,
                openapi => $c->backend->list( $c->stash( 'collection' ) ),
            );
        },
    );

    $app->routes->post( '/:collection' )->name( 'add_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 201,
                openapi => $c->backend->create( $c->stash( 'collection' ), $c->req->json ),
            );
        },
    );

    $app->routes->get( '/:collection/:id' )->name( 'get_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 200,
                openapi => $c->backend->get( $c->stash( 'collection' ), $c->stash( 'id' ) ),
            );
        },
    );

    $app->routes->put( '/:collection/:id' )->name( 'set_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            $c->backend->set( $c->stash( 'collection' ), $c->stash( 'id' ), $c->req->json );
            return $c->render(
                status => 204,
                openapi => '',
            );
        },
    );

    $app->routes->delete( '/:collection/:id' )->name( 'delete_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            return $c->render(
                status => 204,
                openapi => $c->backend->delete( $c->stash( 'collection' ), $c->stash( 'id' ) ),
            );
        },
    );

    $app->plugin( OpenAPI => {
        spec => {
            info => $app->config->{info},
            swagger => '2.0',
            host => hostname(),
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
        },
    } );

}


1;

