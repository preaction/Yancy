package Yancy::Plugin::Editor;
our $VERSION = '1.031';
# ABSTRACT: Yancy content editor, admin, and management application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        read_schema => 1,
        editor => {
            # XXX
        },
    };

=head1 DESCRIPTION

XXX

=head1 CONFIGURATION

This plugin has the following configuration options.

XXX schema openapi default_controller backend moniker

=over

=item route

A base route to add Yancy to. This allows you to customize the URL
and add authentication or authorization. Defaults to allowing access
to the Yancy web application under C</yancy>, and the REST API under
C</yancy/api>.

=item return_to

The URL to use for the "Back to Application" link. Defaults to C</>.

=back

=head1 HELPERS

=head2 yancy.editor.include

    $app->yancy->editor->include( $template_name );

Include a template in the editor, before the rest of the editor. Use this
to add your own L<Vue.JS|http://vuejs.org> components to the editor.

=head2 yancy.editor.menu

    $app->yancy->editor->menu( $category, $title, $config );

Add a menu item to the editor. The C<$category> is the title of the category
in the sidebar. C<$title> is the title of the menu item. C<$config> is a
hash reference with the following keys:

=over

=item component

The name of a Vue.JS component to display for this menu item. The
component will take up the entire main area of the application, and will
be kept active even after another menu item is selected.

=back

Yancy plugins should use the category C<Plugins>. Other categories are
available for custom applications.

    app->yancy->editor->include( 'plugin/editor/custom_element' );
    app->yancy->editor->menu(
        'Plugins', 'Custom Item',
        {
            component => 'custom-element',
        },
    );
    __END__
    @@ plugin/editor/custom_element.html.ep
    <template id="custom-element-template">
        <div :id="'custom-element'">
            Hello, world!
        </div>
    </template>
    %= javascript begin
        Vue.component( 'custom-element', {
            template: '#custom-element-template',
        } );
    % end

=for html

<img alt="screenshot of yancy editor showing custom element"
    src="https://raw.github.com/preaction/Yancy/master/eg/doc-site/public/screenshot-custom-element.png?raw=true" />

=head2 yancy.editor.route

Get the route where the editor will appear.

=head2 yancy.editor.openapi

    my $openapi = $c->yancy->openapi;

Get the L<Mojolicious::Plugin::OpenAPI> object containing the OpenAPI
interface for this Yancy API.

=head1 TEMPLATES

=head2 yancy/editor.html.ep

This is the main Yancy web application. You should not override this. If
you need to, consider filing a bug report or feature request.

=head1 SEE ALSO

L<Yancy::Help::Config>, L<Mojolicious::Plugin::Yancy>, L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON qw( true false );
use Mojo::Util qw( url_escape );
use Sys::Hostname qw( hostname );
use Yancy::Util qw( derp currym );

has moniker => 'editor';
has route =>;
has includes => sub { [] };
has menu_items => sub { +{} };

sub _helper_name {
    my ( $self, $name ) = @_;
    return join '.', 'yancy', $self->moniker, $name;
}

sub register {
    my ( $self, $app, $config ) = @_;

    for my $key ( grep exists $config->{ $_ }, qw( moniker ) ) {
        $self->$key( $config->{ $key } );
    }
    $config->{default_controller} //= $config->{api_controller} // 'Yancy';
    if ( $config->{api_controller} ) {
        derp 'api_controller configuration is deprecated. Use editor.default_controller instead';
    }

    my $route = $config->{route} // $app->routes->any( '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );

    # Create authentication for editor. We need to delay fetching this
    # callback until after startup is complete so that any auth plugin
    # can be added.
    my $auth_under = sub {
        my ( $c ) = @_;
        state $auth_cb = $c->yancy->can( 'auth' )
                    && $c->yancy->auth->can( 'require_user' )
                    && $c->yancy->auth->require_user( $config->{require_user} || () );
        if ( !$auth_cb && !exists $config->{require_user} ) {
            derp qq{*** Editor without authentication is deprecated and will be\n}
                . qq{removed in v2.0. Configure an Auth plugin or set \n}
                . qq{`editor.require_user => undef` to silence this warning\n};
        }
        return $auth_cb ? $auth_cb->( $c ) : 1;
    };
    $route = $route->under( $auth_under );

    # Routes
    $route->get( '/' )->name( 'yancy.index' )
        ->to(
            template => 'yancy/index',
            controller => $config->{default_controller},
            action => 'index',
        );

    $app->helper( $self->_helper_name( 'menu' ), currym( $self, '_helper_menu' ) );
    $app->helper( $self->_helper_name( 'include' ), currym( $self, '_helper_include' ) );
    $app->helper( $self->_helper_name( 'route' ), sub { $route } );
    $app->helper( 'yancy.route', sub {
        derp 'yancy.route helper is deprecated. Use yancy.editor.route instead';
        return $self->route;
    } );
    $self->route( $route );

    my $spec;
    if ( $config->{openapi} && keys %{ $config->{openapi} } ) {
        $spec = $config->{openapi};
    }
    else {
        # Add OpenAPI spec
        $spec = $self->_openapi_spec_from_schema( $config );
    }
    $self->_openapi_spec_add_mojo( $spec, $config );

    my $openapi = $app->plugin( OpenAPI => {
        route => $route->any( '/api' )->name( 'yancy.api' ),
        spec => $spec,
        default_response_name => '_Error',
    } );
    $app->helper( 'yancy.openapi' => sub {
        derp 'yancy.openapi helper is deprecated. Use yancy.editor.openapi instead';
        return $openapi;
    } );
    $app->helper( $self->_helper_name( 'openapi' ) => sub { $openapi } );

    # Add supported formats to silence warnings from JSON::Validator
    my $formats = $openapi->validator->formats;
    $formats->{ password } = sub { undef };
    $formats->{ markdown } = sub { undef };
    $formats->{ tel } = sub { undef };
}

sub _helper_include {
    my ( $self, $c, @includes ) = @_;
    if ( @includes ) {
        push @{ $self->includes }, @includes;
    }
    return $self->includes;
}

sub _helper_menu {
    my ( $self, $c, $category, $title, $config ) = @_;
    if ( $config ) {
        push @{ $self->menu_items->{ $category } }, {
            %$config,
            title => $title,
        };
    }
    return $self->menu_items;
}

sub _openapi_find_schema_name {
    my ( $self, $path, $pathspec ) = @_;
    return $pathspec->{'x-schema'} if $pathspec->{'x-schema'};
    my $schema_name;
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
        die "$method '$path' = $this_ref but also '$schema_name'"
            if $this_ref and $schema_name and $this_ref ne $schema_name;
        $schema_name = $this_ref;
    }
    if ( !$schema_name ) {
        ($schema_name) = $path =~ m#^/([^/]+)#;
        die "No schema found in '$path'" if !$schema_name;
    }
    $schema_name;
}

# mutates $spec
sub _openapi_spec_add_mojo {
    my ( $self, $spec, $config ) = @_;
    for my $path ( keys %{ $spec->{paths} } ) {
        my $pathspec = $spec->{paths}{ $path };
        my $schema = $self->_openapi_find_schema_name( $path, $pathspec );
        die "Path '$path' had non-existent schema '$schema'"
            if !$spec->{definitions}{$schema};
        for my $method ( grep !/^(parameters$|x-)/, keys %{ $pathspec } ) {
            my $op_spec = $pathspec->{ $method };
            my $mojo = $self->_openapi_spec_infer_mojo( $path, $pathspec, $method, $op_spec );
            # XXX Allow overriding controller on a per-schema basis
            # This gives more control over how a certain schema's items
            # are written/read from the database
            $mojo->{controller} = $config->{default_controller};
            $mojo->{schema} = $schema;
            my @filters = (
                @{ $pathspec->{ 'x-filter' } || [] },
                @{ $op_spec->{ 'x-filter' } || [] },
            );
            $mojo->{filters} = \@filters if @filters;
            my @filters_out = (
                @{ $pathspec->{ 'x-filter-output' } || [] },
                @{ $op_spec->{ 'x-filter-output' } || [] },
            );
            $mojo->{filters_out} = \@filters_out if @filters_out;
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
                action => 'get',
                id_field => $id_field,
                format => 'json',
            };
        }
        else {
            # per-schema - GET = "list"
            return {
                action => 'list',
                format => 'json',
            };
        }
    } elsif ( $method eq 'post' ) {
        return {
            action => 'set',
            format => 'json',
        };
    } elsif ( $method eq 'put' ) {
        die "'$method' $path needs id_field" if !$id_field;
        return {
            action => 'set',
            id_field => $id_field,
            format => 'json',
        };
    } elsif ( $method eq 'delete' ) {
        die "'$method' $path needs id_field" if !$id_field;
        return {
            action => 'delete',
            id_field => $id_field,
            format => 'json',
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
    for my $schema_name ( keys %{ $config->{schema} } ) {
        # Set some defaults so users don't have to type as much
        my $schema = $config->{schema}{ $schema_name };
        next if $schema->{ 'x-ignore' };
        my $id_field = $schema->{ 'x-id-field' } // 'id';
        my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
        my $props = $schema->{properties}
            || $config->{schema}{ $real_schema_name }{properties};
        my %props = %$props;

        $definitions{ $schema_name } = $schema;

        for my $prop ( keys %props ) {
            $props{ $prop }{ type } ||= 'string';
        }

        $paths{ '/' . $schema_name } = {
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
                    } } grep !exists( $props{ $_ }{'$ref'} ), sort keys %props,
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
                                    items => { '$ref' => "#/definitions/" . url_escape $schema_name },
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
            $schema->{'x-view'} ? () : (post => {
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/" . url_escape $schema_name },
                    },
                ],
                responses => {
                    201 => {
                        description => "Entry was created",
                        schema => {
                            '$ref' => sprintf "#/definitions/%s/properties/%s",
                                      map { url_escape $_ } $schema_name, $id_field,
                        },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => "#/definitions/_Error" },
                    },
                },
            }),
        };

        $paths{ sprintf '/%s/{%s}', $schema_name, $id_field } = {
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
                        schema => { '$ref' => "#/definitions/" . url_escape $schema_name },
                    },
                    default => {
                        description => "Unexpected error",
                        schema => { '$ref' => '#/definitions/_Error' },
                    }
                }
            },

            $schema->{'x-view'} ? () : (put => {
                description => "Update a single item",
                parameters => [
                    {
                        name => "newItem",
                        in => "body",
                        required => true,
                        schema => { '$ref' => "#/definitions/" . url_escape $schema_name },
                    }
                ],
                responses => {
                    200 => {
                        description => "Item was updated",
                        schema => { '$ref' => "#/definitions/" . url_escape $schema_name },
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
            }),
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


1;
