package Mojolicious::Plugin::Yancy;
our $VERSION = '1.052';
# ABSTRACT: Embed a simple admin CMS into your Mojolicious application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://postgres@/mydb',
        schema => { ... },
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
            schema => { ... },
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

A base route to add the Yancy editor to. This allows you to customize
the URL and add authentication or authorization. Defaults to allowing
access to the Yancy web application under C</yancy>, and the REST API
under C</yancy/api>.

This can be a string or a L<Mojolicious::Routes::Route> object.

    # These are equivalent
    use Mojolicious::Lite;
    plugin Yancy => { route => app->routes->any( '/admin' ) };
    plugin Yancy => { route => '/admin' };

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
C<schema> configuration as needed.

=head2 yancy.backend

    my $be = $c->yancy->backend;

Get the Yancy backend object. By default, gets the backend configured
while loading the Yancy plugin. Requests can override the backend by
setting the C<backend> stash value. See L<Yancy::Backend> for the
methods you can call on a backend object and their purpose.

=head2 yancy.plugin

Add a Yancy plugin. Yancy plugins are Mojolicious plugins that require
Yancy features and are found in the L<Yancy::Plugin> namespace.

    use Mojolicious::Lite;
    plugin 'Yancy';
    app->yancy->plugin( 'Auth::Basic', { schema => 'users' } );

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

    my @items = $c->yancy->list( $schema, \%param, \%opt );

Get a list of items from the backend. C<$schema> is a schema
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

    my $item = $c->yancy->get( $schema, $id );

Get an item from the backend. C<$schema> is the schema name.
C<$id> is the ID of the item to get. See L<Yancy::Backend/get>.

This helper will filter out password values in the returned data. To get
all the data, use the L<backend|/yancy.backend> helper to access the
backend directly.

=head2 yancy.set

    $c->yancy->set( $schema, $id, $item_data, %opt );

Update an item in the backend. C<$schema> is the schema name.
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

    my $item = $c->yancy->create( $schema, $item_data );

Create a new item. C<$schema> is the schema name. C<$item_data>
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

    $c->yancy->delete( $schema, $id );

Delete an item from the backend. C<$schema> is the schema name.
C<$id> is the ID of the item to delete. See L<Yancy::Backend/delete>.

=head2 yancy.validate

    my @errors = $c->yancy->validate( $schema, $item, %opt );

Validate the given C<$item> data against the configuration for the
C<$schema>. If there are any errors, they are returned as an array
of L<JSON::Validator::Error> objects. C<%opt> is a list of options with
the following keys:

=over

=item * properties - An arrayref of properties to validate, for partial updates

=back

See L<JSON::Validator/validate> for more details.

=head2 yancy.form

By default, the L<Yancy::Plugin::Form::Bootstrap4> form plugin is
loaded.  You can override this with your own form plugin. See
L<Yancy::Plugin::Form> for more information.

=head2 yancy.file

By default, the L<Yancy::Plugin::File> plugin is loaded to handle file
uploading and file management. The default path for file uploads is
C<$MOJO_HOME/public/uploads>. You can override this with your own file
plugin. See L<Yancy::Plugin::File> for more information.

=head2 yancy.filter.add

    my $filter_sub = sub { my ( $field_name, $field_value, $field_conf, @params ) = @_; ... }
    $c->yancy->filter->add( $name => $filter_sub );

Create a new filter. C<$name> is the name of the filter to give in the
field's configuration. C<$subref> is a subroutine reference that accepts
at least three arguments:

=over

=item * $name - The name of the schema/field being filtered

=item * $value - The value to filter, either the entire item, or a single field

=item * $conf - The configuration for the schema/field

=item * @params - Other parameters if configured

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
        schema => {
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

The same filter, but also configurable with extra parameters:

    my $digest = sub {
        my ( $field_name, $field_value, $field_conf, @params ) = @_;
        my $type = ( $params[0] || $field_conf->{ 'x-digest' } )->{ type };
        Digest->new( $type )->add( $field_value )->b64digest;
        $field_value . $params[0];
    };
    $c->yancy->filter->add( 'digest' => $digest );

The alternative configuration:

    # mysite.conf
    {
        schema => {
            users => {
                properties => {
                    username => { type => 'string' },
                    password => {
                        type => 'string',
                        format => 'password',
                        'x-filter' => [ [ digest => { type => 'SHA-1' } ] ],
                    },
                },
            },
        },
    }

Schemas can also have filters. A schema filter will get the
entire hash reference as its value. For example, here's a filter that
updates the C<last_updated> field with the current time:

    $c->yancy->filter->add( 'timestamp' => sub {
        my ( $schema_name, $item, $schema_conf ) = @_;
        $item->{last_updated} = time;
        return $item;
    } );

And you configure this on the schema using C<< x-filter >>:

    # mysite.conf
    {
        schema => {
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

You can configure filters on OpenAPI operations' inputs. These will
probably want to operate on hash-refs as in the schema-level filters
above. The config passed will be an empty hash. The filter can be applied
to either or both of the path, or the individual operation, and will be
executed in that order. E.g.:

    # mysite.conf
    {
        openapi => {
            definitions => {
                people => {
                    properties => {
                        name => { type => 'string' },
                        address => { type => 'string' },
                        last_updated => { type => 'datetime' },
                    },
                },
            },
            paths => {
                "/people" => {
                    # could also have x-filter here
                    "post" => {
                        'x-filter' => [ 'timestamp' ],
                        # ...
                    },
                },
            }
        },
    }

You can also configure filters on OpenAPI operations' outputs, this time
with the key C<x-filter-output>. Again, the config passed will be an empty
hash. The filter can be applied to either or both of the path, or the
individual operation, and will be executed in that order. E.g.:

    # mysite.conf
    {
        openapi => {
            paths => {
                "/people" => {
                    'x-filter-output' => [ 'timestamp' ],
                    # ...
                },
            }
        },
    }

=head3 Supplied filters

These filters are always installed.

=head4 yancy.from_helper

The first configured parameter is the name of an installed Mojolicious
helper. That helper will be called, with any further supplied parameters,
and the return value will be used as the value of that field /
item. E.g. with this helper:

    $app->helper( 'current_time' => sub { scalar gmtime } );

This configuration will achieve the same as the above with C<last_updated>:

    # mysite.conf
    {
        schema => {
            people => {
                properties => {
                    name => { type => 'string' },
                    address => { type => 'string' },
                    last_updated => {
                        type => 'datetime',
                        'x-filter' => [ [ 'yancy.from_helper' => 'current_time' ] ],
                    },
                },
            },
        },
    }

=head4 yancy.overlay_from_helper

Intended to be used for "items" rather than individual fields, as it
will only work when the "value" parameter is a hash-ref.

The configured parameters are supplied in pairs. The first item in the
pair is the string key in the hash-ref. The second is either the name of
a helper, or an array-ref with the first entry as such a helper-name,
followed by parameters to pass that helper. For each pair, the helper
will be called, and its return value set as the relevant key's value.
E.g. with this helper:

    $app->helper( 'current_time' => sub { scalar gmtime } );

This configuration will achieve the same as the above with C<last_updated>:

    # mysite.conf
    {
        schema => {
            people => {
                'x-filter' => [
                    [ 'yancy.overlay_from_helper' => 'last_updated', 'current_time' ]
                ],
                properties => {
                    name => { type => 'string' },
                    address => { type => 'string' },
                    last_updated => { type => 'datetime' },
                },
            },
        },
    }

=head4 yancy.wrap

The configured parameters are a list of strings. For each one, the
original value will be wrapped in a hash with that string as the key,
and the previous value as the value. E.g. with this config:

    'x-filter-output' => [
        [ 'yancy.wrap' => qw(user login) ],
    ],

The original value of say C<{ user => 'bob', password => 'h12' }>
will become:

    {
        login => {
            user => { user => 'bob', password => 'h12' }
        }
    }

The utility of this comes from being able to expressively translate to
and from a simple database structure to a situation where simple values
or JSON objects need to be wrapped in objects one or two deep.

=head4 yancy.unwrap

This is the converse of the above. The configured parameters are a
list of strings. For each one, the original value (a hash-ref) will be
"unwrapped" by looking in the given hash and extracting the value whose
key is that string. E.g. with this config:

    'x-filter' => [
        [ 'yancy.unwrap' => qw(login user) ],
    ],

This will achieve the reverse of the transformation given in
L</yancy.wrap> above. Note that obviously the order of arguments is
inverted, since this operates outside-inward, while C<yancy.wrap>
operates inside-outward.

=head2 yancy.filter.apply

    my $filtered_data = $c->yancy->filter->apply( $schema, $item_data );

Run the configured filters on the given C<$item_data>. C<$schema> is
a schema name. Returns the hash of C<$filtered_data>.

The property-level filters will run before any schema-level filter,
so that schema-level filters can take advantage of any values set by
the inner filters.

=head2 yancy.filters

Returns a hash-ref of all configured helpers, mapping the names to
the code-refs.

=head2 yancy.schema

    my $schema = $c->yancy->schema( $name );
    $c->yancy->schema( $name => $schema );
    my $schemas = $c->yancy->schema;

Get or set the JSON schema for the given schema C<$name>. If no
schema name is given, returns a hashref of all the schema.

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

=back

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy;
use Mojo::JSON qw( true false decode_json );
use Mojo::File qw( path );
use Mojo::Loader qw( load_class );
use Yancy::Util qw( load_backend curry copy_inline_refs derp is_type );
use JSON::Validator::OpenAPI::Mojolicious;
use Storable qw( dclone );
use Scalar::Util qw( blessed );

has _filters => sub { {} };

sub register {
    my ( $self, $app, $config ) = @_;

    if ( $config->{collections} ) {
        derp '"collections" stash key is now "schema" in Yancy configuration';
        $config->{schema} = $config->{collections};
    }
    die "Cannot pass both openapi AND (schema or read_schema)"
        if $config->{openapi}
            && ( $config->{schema} || $config->{read_schema} );

    # Load the backend and schema
    $config = { %$config };
    $app->helper( 'yancy.backend' => sub {
        my ( $c ) = @_;
        state $default_backend = load_backend( $config->{backend}, $config->{schema} || $config->{openapi}{definitions} );
        if ( my $backend = $c->stash( 'backend' ) ) {
            $c->app->log->debug( 'Using override backend from stash: ' . ref $backend );
            return $backend;
        }
        return $default_backend;
    } );
    if ( $config->{schema} || $config->{read_schema} ) {
        $config->{schema} = $config->{schema} ? dclone( $config->{schema} ) : {};

        if ( $config->{read_schema} ) {
            my $schema = $app->yancy->backend->read_schema;
            # ; use Data::Dumper;
            # ; say 'Read schema: ' . Dumper $schema;
            for my $c ( keys %$schema ) {
                _merge_schema( $config->{schema}{ $c } ||= {}, $schema->{ $c } );
            }
        }
        # read_schema on schema
        for my $schema_name ( keys %{ $config->{schema} } ) {
            my $schema = $config->{schema}{ $schema_name };
            if ( delete $schema->{read_schema} ) {
                _merge_schema( $schema, $app->yancy->backend->read_schema( $schema_name ) );
            }
        }

        # ; warn 'Merged Schema';
        # ; use Data::Dumper;
        # ; warn Dumper $config->{schema};

        # Sanity check for the schema.
        for my $schema_name ( keys %{ $config->{schema} } ) {
            my $schema = $config->{schema}{ $schema_name };
            next if $schema->{ 'x-ignore' }; # XXX Should we just delete x-ignore schema?
            $schema->{ type } //= 'object';
            my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
            my $props = $schema->{properties}
                || $config->{schema}{ $real_schema_name }{properties};
            my $id_field = $schema->{ 'x-id-field' } // 'id';
            if ( !$props->{ $id_field } ) {
                die sprintf "ID field missing in properties for schema '%s', field '%s'."
                    . " Add x-id-field to configure the correct ID field name, or"
                    . " add x-ignore to ignore this schema.",
                        $schema_name, $id_field;
            }
        }
    }
    elsif ( $config->{openapi} ) {
        $config->{openapi} = _ensure_json_data( $app, $config->{openapi} );
        $config->{schema} = dclone( $config->{openapi}{definitions} );
    }

    # Resources and templates
    my $share = path( __FILE__ )->sibling( 'Yancy' )->child( 'resources' );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths }, $share->child( 'templates' )->to_string;
    push @{$app->routes->namespaces}, 'Yancy::Controller';
    push @{ $app->commands->namespaces }, 'Yancy::Command';

    # Helpers
    $app->helper( 'yancy.config' => sub { return $config } );
    $app->helper( 'yancy.plugin' => \&_helper_plugin );
    $app->helper( 'yancy.schema' => \&_helper_schema );
    $app->helper( 'yancy.list' => \&_helper_list );
    $app->helper( 'yancy.get' => \&_helper_get );
    $app->helper( 'yancy.delete' => \&_helper_delete );
    $app->helper( 'yancy.set' => \&_helper_set );
    $app->helper( 'yancy.create' => \&_helper_create );
    $app->helper( 'yancy.validate' => \&_helper_validate );
    $app->helper( 'yancy.routify' => \&_helper_routify );

    # Default form is Bootstrap4. Any form plugin added after this will
    # override this one
    $app->yancy->plugin( 'Form::Bootstrap4' );
    $app->yancy->plugin( File => {
        path => $app->home->child( 'public/uploads' ),
    } );

    $self->_helper_filter_add( undef, 'yancy.from_helper' => sub {
        my ( $field_name, $field_value, $field_conf, @params ) = @_;
        my $which_helper = shift @params;
        my $helper = $app->renderer->get_helper( $which_helper );
        $helper->( @params );
    } );
    $self->_helper_filter_add( undef, 'yancy.overlay_from_helper' => sub {
        my ( $field_name, $field_value, $field_conf, @params ) = @_;
        my %new_item = %$field_value;
        while ( my ( $key, $helper ) = splice @params, 0, 2 ) {
            ( $helper, my @this_params ) = @$helper if ref $helper eq 'ARRAY';
            my $v = $app->renderer->get_helper( $helper )->( @this_params );
            $new_item{ $key } = $v;
        }
        \%new_item;
    } );
    $self->_helper_filter_add( undef, 'yancy.wrap' => sub {
        my ( $field_name, $field_value, $field_conf, @params ) = @_;
        $field_value = { $_ => $field_value } for @params;
        $field_value;
    } );
    $self->_helper_filter_add( undef, 'yancy.unwrap' => sub {
        my ( $field_name, $field_value, $field_conf, @params ) = @_;
        $field_value = $field_value->{$_} for @params;
        $field_value;
    } );
    for my $name ( keys %{ $config->{filters} } ) {
        $self->_helper_filter_add( undef, $name, $config->{filters}{$name} );
    }
    $app->helper( 'yancy.filter.add' => curry( \&_helper_filter_add, $self ) );
    $app->helper( 'yancy.filter.apply' => curry( \&_helper_filter_apply, $self ) );
    $app->helper( 'yancy.filters' => sub {
        state $filters = $self->_filters;
    } );

    # Add the default editor unless the user explicitly disables it
    if ( !exists $config->{editor} || defined $config->{editor} ) {
        $app->yancy->plugin( 'Editor' => {
            (
                map { $_ => $config->{ $_ } }
                grep { defined $config->{ $_ } }
                qw( route openapi schema api_controller info host return_to ),
            ),
            %{ $config->{editor} // {} },
        } );
    }
}

# if false or a ref, just returns same
# if non-ref, treat as JSON-containing file, load and decode
sub _ensure_json_data {
    my ( $app, $data ) = @_;
    return $data if !$data or ref $data;
    # assume a file in JSON format: load and parse it
    decode_json $app->home->child( $data )->slurp;
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
    $formats->{ filepath } = sub { undef };
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
        return $c->yancy->config->{schema};
    }
    if ( $schema ) {
        $c->yancy->config->{schema}{ $name } = $schema;
        return;
    }
    return copy_inline_refs( $c->yancy->config->{schema}, "/$name" );
}

sub _helper_list {
    my ( $c, $schema_name, @args ) = @_;
    my @items = @{ $c->yancy->backend->list( $schema_name, @args )->{items} };
    my $schema = $c->yancy->schema( $schema_name );
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };
        if ( $prop->{format} && $prop->{format} eq 'password' ) {
            delete $_->{ $prop_name } for @items;
        }
    }
    return @items;
}

sub _helper_get {
    my ( $c, $schema_name, $id, @args ) = @_;
    my $item = $c->yancy->backend->get( $schema_name, $id, @args );
    my $schema = $c->yancy->schema( $schema_name );
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };
        if ( $prop->{format} && $prop->{format} eq 'password' ) {
            delete $item->{ $prop_name };
        }
    }
    $item = $c->yancy->filter->apply( $schema, $item, 'x-filter-output' );
    return $item;
}

sub _helper_delete {
    my ( $c, @args ) = @_;
    return $c->yancy->backend->delete( @args );
}

sub _helper_set {
    my ( $c, $schema, $id, $item, %opt ) = @_;
    my %validate_opt =
        map { $_ => $opt{ $_ } }
        grep { exists $opt{ $_ } }
        qw( properties );
    if ( my @errors = $c->yancy->validate( $schema, $item, %validate_opt ) ) {
        $c->app->log->error(
            sprintf 'Error validating item with ID "%s" in schema "%s": %s',
            $id, $schema,
            join ', ', @errors
        );
        die \@errors;
    }
    $item = $c->yancy->filter->apply( $schema, $item );
    my $ret = eval { $c->yancy->backend->set( $schema, $id, $item ) };
    if ( $@ ) {
        $c->app->log->error(
            sprintf 'Error setting item with ID "%s" in schema "%s": %s',
            $id, $schema, $@,
        );
        die $@;
    }
    return $ret;
}

sub _helper_create {
    my ( $c, $schema, $item ) = @_;

    my $props = $c->yancy->schema( $schema )->{properties};
    $item->{ $_ } = $props->{ $_ }{default}
        for grep !exists $item->{ $_ } && exists $props->{ $_ }{default},
        keys %$props;

    if ( my @errors = $c->yancy->validate( $schema, $item ) ) {
        $c->app->log->error(
            sprintf 'Error validating new item in schema "%s": %s',
            $schema,
            join ', ', @errors
        );
        die \@errors;
    }

    $item = $c->yancy->filter->apply( $schema, $item );
    my $ret = eval { $c->yancy->backend->create( $schema, $item ) };
    if ( $@ ) {
        $c->app->log->error(
            sprintf 'Error creating item in schema "%s": %s',
            $schema, $@,
        );
        die $@;
    }
    return $ret;
}

sub _helper_validate {
    my ( $c, $schema_name, $input_item, %opt ) = @_;
    state $validator = {};
    my $schema = $c->yancy->schema( $schema_name );
    my $v = $validator->{ $schema } ||= _build_validator( $schema );

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

    my %check_item = %$input_item;
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };

        # These blocks fix problems with validation only. If the
        # problem is the database understanding the value, it must be
        # fixed in the backend class.

        # Pre-filter booleans
        if ( is_type( $prop->{type}, 'boolean' ) && defined $check_item{ $prop_name } ) {
            my $value = $check_item{ $prop_name };
            if ( $value eq 'false' or !$value ) {
                $value = false;
            } else {
                $value = true;
            }
            $check_item{ $prop_name } = $value;
        }
        # An empty date-time, date, or time must become undef: The empty
        # string will never pass the format check, but properties that
        # are allowed to be null can be validated.
        if ( is_type( $prop->{type}, 'string' ) && $prop->{format} && $prop->{format} =~ /^(?:date-time|date|time)$/ ) {
            if ( exists $check_item{ $prop_name } && !$check_item{ $prop_name } ) {
                $check_item{ $prop_name } = undef;
            }
            # The "now" special value will not validate yet, but will be
            # replaced by the Backend with something useful
            elsif ( ($check_item{ $prop_name }//'') eq 'now' ) {
                delete $check_item{ $prop_name };
            }
        }
        # Always add dummy passwords to pass required checks
        if ( $prop->{format} && $prop->{format} eq 'password' && !$check_item{ $prop_name } ) {
            # Add to a new copy of the item so we don't actually change
            # the item
            %check_item = ( %check_item, $prop_name => '<PASSWORD>' );
        }
    }

    my @errors = $v->validate_input( \%check_item, @args );
    return @errors;
}

sub _helper_filter_apply {
    my ( $self, $c, $schema_name, $item, $output ) = @_;
    my $filter_type = $output ? 'x-filter-output' : 'x-filter';
    my $schema = $c->yancy->schema( $schema_name );
    my $filters = $self->_filters;
    for my $key ( keys %{ $schema->{properties} } ) {
        next unless my $prop_filters = $schema->{properties}{ $key }{ $filter_type };
        for my $filter ( @{ $prop_filters } ) {
            ( $filter, my @params ) = @$filter if ref $filter eq 'ARRAY';
            my $sub = $filters->{ $filter };
            die "Unknown filter: $filter (schema: $schema_name, field: $key)"
                unless $sub;
            $item = { %$item, $key => $sub->(
                $key, $item->{ $key }, $schema->{properties}{ $key }, @params
            ) };
        }
    }
    if ( my $schema_filters = $schema->{$filter_type} ) {
        for my $filter ( @{ $schema_filters } ) {
            ( $filter, my @params ) = @$filter if ref $filter eq 'ARRAY';
            my $sub = $filters->{ $filter };
            die "Unknown filter: $filter (schema: $schema_name)"
                unless $sub;
            $item = $sub->( $schema_name, $item, $schema, @params );
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

sub _helper_routify {
    my ( $self, @args ) = @_;
    for my $maybe_route ( @args ) {
        next unless defined $maybe_route;
        return blessed $maybe_route && $maybe_route->isa( 'Mojolicious::Routes::Route' )
            ? $maybe_route
            : $self->app->routes->any( $maybe_route )
            ;
    }
}

1;
