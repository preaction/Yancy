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
use File::Share qw( dist_dir );
use File::Spec::Functions qw( catdir );

sub startup( $app ) {

    $app->plugin( Config => { default => { } } );

    # Compile JS and CSS assets
    $app->plugin( 'AssetPack', { pipes => [qw( Css JavaScript )] } );
    $app->asset->store->paths([
        catdir( dist_dir( 'Yancy' ), 'node_modules' ),
        @{ $app->static->paths },
    ]);

    $app->asset->process(
        'prereq.js' => qw(
            https://cdnjs.cloudflare.com/ajax/libs/jquery/3.2.1/jquery.min.js
            https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.8/umd/popper.min.js
            https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-beta/js/bootstrap.min.js
            https://cdnjs.cloudflare.com/ajax/libs/vue/2.5.3/vue.min.js
        ),
    );

    $app->asset->process(
        'prereq.css' => qw(
            https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-beta/css/bootstrap.min.css
        ),
    );

    # $app->asset->process(
    #     'prereq.js' => qw(
    #         /jquery/dist/jquery.js
    #         /bootstrap/dist/js/bootstrap.js
    #         /vue/dist/js/vue.js
    #     ),
    # );

    # $app->asset->process(
    #     'prereq.css' => qw(
    #         /bootstrap/dist/css/bootstrap.css
    #         /bootstrap/dist/css/bootstrap-theme.css
    #         /font-awesome/css/font-awesome.css
    #     ),
    # );

    # Add static paths to find fonts
    push @{ $app->static->paths },
        catdir( dist_dir( 'Yancy' ), 'node_modules', 'font-awesome' );

    $app->helper( backend => sub {
        state $backend;
        if ( !$backend ) {
            my ( $type ) = $app->config->{yancy}{backend} =~ m{^([^:]+)};
            my $class = 'Yancy::Backend::' . ucfirst $type;
            use_module( $class );
            $backend = $class->new( $app->config->{yancy}{backend} );
        }
        return $backend;
    } );

    my ( %definitions, %paths );
    my %config = $app->config->{yancy}->%*;
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
                status => 200,
                openapi => $c->backend->get( $c->stash( 'collection' ), $c->stash( 'id' ) ),
            );
        },
    );

    $app->routes->delete( '/:collection/:id' )->name( 'delete_item' )->to(
        cb => sub( $c ) {
            return unless $c->openapi->valid_input;
            $c->backend->delete( $c->stash( 'collection' ), $c->stash( 'id' ) );
            return $c->rendered( 204 );
        },
    );

    $app->plugin( OpenAPI => {
        spec => {
            info => $app->config->{yancy}{info},
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

    $app->routes->get( '/' )->name( 'index' )->to( '#index' );
    push @{$app->renderer->classes}, __PACKAGE__;
    push @{$app->static->classes},   __PACKAGE__;

}


1;

__DATA__
@@ index.html.ep
<!DOCTYPE html>
<html>
    <head>
        <title>Yancy CMS</title>
        %= asset 'prereq.css'
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"
            rel="stylesheet">
        %= asset 'prereq.js'

        <style>
            .data-table tbody tr:nth-child( even ) div {
                height: 0;
                overflow: hidden;
            }
            .data-table tbody tr:nth-child( odd ).open + tr td {
                padding-bottom: 0.75em;
            }
            .data-table tbody tr:nth-child( odd ).open + tr div {
                height: auto;
            }
            .data-table tbody tr:nth-child( even ) td {
                padding: 0;
                border: 0;
            }
            .data-table textarea, .add-item textarea {
                width: 100%;
            }
            .add-item {
                margin-top: 0.75em;
            }
        </style>

    </head>
    <body>
        <nav class="navbar navbar-expand-lg navbar-light bg-light">
          <a class="navbar-brand" href="<%= url_for 'index' %>">Yancy</a>
          <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
            <span class="navbar-toggler-icon"></span>
          </button>

          <div class="collapse navbar-collapse" id="navbarSupportedContent">
            <!--
            <ul class="navbar-nav mr-auto">
              <li class="nav-item active">
                <a class="nav-link" href="#">Home <span class="sr-only">(current)</span></a>
              </li>
              <li class="nav-item">
                <a class="nav-link" href="#">Link</a>
              </li>
              <li class="nav-item dropdown">
                <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                  Dropdown
                </a>
                <div class="dropdown-menu" aria-labelledby="navbarDropdown">
                  <a class="dropdown-item" href="#">Action</a>
                  <a class="dropdown-item" href="#">Another action</a>
                  <div class="dropdown-divider"></div>
                  <a class="dropdown-item" href="#">Something else here</a>
                </div>
              </li>
              <li class="nav-item">
                <a class="nav-link disabled" href="#">Disabled</a>
              </li>
            </ul>
            -->
          </div>
        </nav>

        <main id="app" class="container-fluid" style="margin-top: 10px">
            <div class="row">
                <div class="col-md-2">
                    <div class="list-group">
                        <!-- collection list -->
                        <a v-for="( val, key ) in collections" href="#"
                            @click.prevent="currentCollection = key"
                            class="list-group-item list-group-item-action"
                            :class="currentCollection == key ? 'active' : ''"
                        >
                            {{ key }}
                        </a>

                    </div>
                </div>
                <div v-show="currentCollection" class="col-md-10">
                    <!-- current collection -->
                    <h2>{{ currentCollection }}</h2>
                    <button @click="refreshCollection()" class="btn btn-primary">Refresh</button>
                    <button @click="showAddItem()" class="btn btn-default">Add Item</button>
                    <div v-if="addingItem" class="add-item">
                        <textarea id="data-add" rows="10">{{ JSON.stringify( this.collections[ this.currentCollection ].operations['add'].schema.example, null, 4 ) }}</textarea>
                        <button @click="addItem()" class="btn btn-primary">Save</button>
                        <button @click="cancelAddItem()" class="btn btn-danger">Cancel</button>
                    </div>

                    <table style="margin-top: 0.5em; width: 100%" class="table data-table">
                        <thead class="thead-light">
                            <tr>
                                <!-- <th><input type="checkbox"></th> -->
                                <th></th>
                                <th v-for="( col, i ) in columns">{{col}}</th>
                            </tr>
                        </thead>
                        <tbody>
                            <template v-for="( row, i ) in rows">
                            <tr :class="openedRow == i ? 'open' : ''">
                                <!-- <td style="width: 2em"><input type="checkbox"></td> -->
                                <td style="width: 4em">
                                    <a href="#" @click.prevent="toggleRow(i)">
                                        <i class="fa fa-pencil-square-o" aria-hidden="true"></i>
                                    </a>
                                    <a href="#" @click.prevent="confirmDeleteItem(i)">
                                        <i class="fa fa-trash-o" aria-hidden="true"></i>
                                    </a>
                                </td>
                                <td v-for="col in columns">
                                    {{ row[col] }}
                                </td>
                            </tr>
                            <tr>
                                <td :colspan="2 + columns.length">
                                    <div>
                                        <textarea :id="'data-' + i" rows="10">{{ JSON.stringify( row, null, 4 ) }}</textarea>
                                        <button @click="saveItem(i)" class="btn btn-primary">Save</button>
                                        <button @click="cancelSaveItem(i)" class="btn btn-danger">Cancel</button>
                                    </div>
                                </td>
                            </tr>
                            </template>
                        </tbody>
                    </table>

                </div>
            </div>

            <div id="confirmDelete" class="modal" tabindex="-1" role="dialog">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Confirm Delete</h5>
                    </div>
                <div class="modal-body">
                    <p>Are you sure you want to delete this item?</p>
                </div>
                <div class="modal-footer">
                    <button @click.prevent="deleteItem()" type="button" class="btn btn-danger">Delete</button>
                    <button @click.prevent="cancelDeleteItem()" type="button" class="btn btn-secondary">Cancel</button>
                </div>
            </div>

        </main>

    </div>
</div>

<script>
var specUrl = '/api';
var app = new Vue({
    el: '#app',
    data: function () {
        return {
            currentCollection: null,
            collections: {},
            openedRow: null,
            deleteIndex: null,
            addingItem: false,
            rows: [],
            columns: [],
        }
    },
    methods: {
        toggleRow: function ( i ) {
            if ( this.openedRow == i ) {
                this.openedRow = null;
            }
            else {
                this.openedRow = i;
            }
        },

        fetchSpec: function () {
            var self = this;
            $.get( specUrl ).done( function ( data, status, jqXHR ) {
                self.parseSpec( data );
            } );
        },

        parseSpec: function ( spec ) {
            var pathParts = [], collectionName, collection, pathObj;
            this.collections = {};

            for ( var pathKey in spec.paths ) {
                pathObj = spec.paths[ pathKey ];

                pathParts = pathKey.split( '/' );
                collectionName = pathParts[1];
                collection = this.collections[ collectionName ];
                if ( !collection ) {
                    collection = this.collections[ collectionName ] = {
                        operations: { }
                    };
                }

                // Array operations
                if ( pathParts.length == 2 ) {
                    if ( pathObj.get ) {
                        collection.operations["list"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.post ) {
                        collection.operations["add"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                }
                // Item operations
                else {
                    if ( pathObj.get ) {
                        collection.operations["get"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.put ) {
                        collection.operations["set"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.delete ) {
                        collection.operations["delete"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                }

                this.currentCollection = "people"; // test
            }
        },

        refreshCollection: function () {
            var coll = this.collections[ this.currentCollection ],
                self = this;
            $.get( coll.operations["list"].url ).done(
                function ( data, status, jqXHR ) {
                    self.rows = data;
                    self.columns = coll.operations["list"].schema['x-list-columns'] || [];
                }
            );
        },

        saveItem: function (i) {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-' + i ).val(),
                url = this.fillUrl( coll.operations['set'].url, this.rows[i] );
            $.ajax(
                {
                    url: url,
                    method: 'PUT',
                    data: value,
                    dataType: "json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.rows[i] = data;
                    self.toggleRow( i );
                }
            );
        },

        cancelSaveItem: function (i) {
            this.toggleRow( i );
        },

        addItem: function (i) {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-add' ).val(),
                url = coll.operations['add'].url;
            $.ajax(
                {
                    url: url,
                    method: 'POST',
                    data: value,
                    dataType: "json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.rows.unshift( data );
                    self.cancelAddItem();
                }
            );
        },

        showAddItem: function () {
            this.addingItem = true;
        },

        cancelAddItem: function () {
            this.addingItem = false;
        },

        confirmDeleteItem: function (i) {
            this.deleteIndex = i;
            $( '#confirmDelete' ).modal( 'show' );
        },

        cancelDeleteItem: function () {
            this.deleteIndex = null;
            $( '#confirmDelete' ).modal( 'hide' );
        },

        deleteItem: function () {
            var i = this.deleteIndex,
                self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-' + i ).val(),
                url = this.fillUrl( coll.operations['delete'].url, this.rows[i] );
            $.ajax(
                {
                    url: url,
                    method: 'DELETE',
                    data: value
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.cancelDeleteItem();
                    self.rows.splice(i,1);
                }
            ).fail(
                function ( jqXHR, status ) {
                    alert( "Failed: " + status );
                }
            );

        },

        fillUrl: function ( tmpl, data ) {
            return tmpl.replace( /\{([^}]+)\}/g, function ( match, field ) {
                return data[field];
            } );
        }

    },
    watch: {
        currentCollection: function () {
            this.data = [];
            this.refreshCollection();
        }
    },
    mounted: function () {
        this.fetchSpec();
    }
});
</script>

    </body>
</html>
