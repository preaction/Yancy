package Mojolicious::Plugin::Yancy;
our $VERSION = '1.089';
# ABSTRACT: Embed a simple admin CMS into your Mojolicious application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => backend => 'sqlite:myapp.db'; # mysql, pg, dbic...
    app->start;

=head1 DESCRIPTION

This plugin allows you to add a simple content management system (CMS)
to administrate content on your L<Mojolicious> site. This includes
a JavaScript web application to edit the content and a REST API to help
quickly build your own application.

=head1 CONFIGURATION

For getting started with a configuration for Yancy, see
the L<"Yancy Guides"|Yancy::Guides>.

Additional configuration keys accepted by the plugin are:

=over

=item backend

In addition to specifying the backend as a single URL (see L<"Database
Backend"|Yancy::Guides::Schema/Database Backend>), you can specify it as
a hashref of C<< class => $db >>. This allows you to share database
connections.

    use Mojolicious::Lite;
    use Mojo::Pg;
    helper pg => sub { state $pg = Mojo::Pg->new( 'postgres:///myapp' ) };
    plugin Yancy => { backend => { Pg => app->pg } };

=item model

(optional) Specify a model class or object that extends L<Yancy::Model>.
By default, will create a basic L<Yancy::Model> object.

    plugin Yancy => { backend => { Pg => app->pg }, model => 'MyApp::Model' };

    my $model = Yancy::Model->with_roles( 'MyRole' );
    plugin Yancy => { backend => { Pg => app->pg }, model => $model };

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

=head2 yancy.model

  my $model = $c->yancy->model;
  my $schema = $c->yancy->model( $schema_name );

Return the L<Yancy::Model> or a L<Yancy::Model::Schema> by name.

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

This helper will validate the data against the configuration.
If validation fails, this helper will throw an
exception with an array reference of L<JSON::Validator::Error> objects.
See L<the validate helper|/yancy.validate>. To bypass validation, use the
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

This helper will validate the data against the configuration.
If validation fails, this helper will throw an
exception with an array reference of L<JSON::Validator::Error> objects.
See L<the validate helper|/yancy.validate>.
To bypass validation, use the
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

=head2 yancy.schema

    my $schema = $c->yancy->schema( $name );
    $c->yancy->schema( $name => $schema );
    my $schemas = $c->yancy->schema;

Get or set the JSON schema for the given schema C<$name>. If no
schema name is given, returns a hashref of all the schema.

=head2 log_die

Raise an exception with L<Mojo::Exception/raise>, first logging
using L<Mojo::Log/fatal> (through the L<C<log> helper|Mojolicious::Plugin::DefaultHelpers/log>.

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
use Yancy::Util qw( load_backend curry copy_inline_refs derp is_type json_validator );
use Yancy::Model;
use Storable qw( dclone );
use Scalar::Util qw( blessed );

# NOTE: This class should largely be setup of paths and helpers. Special
# handling of route stashes should be in the controller object. Special
# handling of data should be in the model.
#
# Code in here is difficult to override for customizations, and should
# be avoided.

sub register {
    my ( $self, $app, $config ) = @_;

    # XXX: Move editor, auth, schema to attributes of this object.
    # That allows for easier extending/replacing of them.
    # XXX: Deprecate direct access to the backend. Backend should be
    # accessed through the schema, if needed.

    # New default for read_schema is on, since it mostly should be
    # on. Any real-world database is going to be painstakingly tedious
    # to type out in JSON schema...
    $config->{read_schema} //= !exists $config->{openapi};

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
            $c->log->debug( 'Using override backend from stash: ' . ref $backend );
            return $backend;
        }
        return $default_backend;
    } );

    if ( $config->{openapi} ) {
        $config->{openapi} = _ensure_json_data( $app, $config->{openapi} );
        $config->{schema} = dclone( $config->{openapi}{definitions} );
    }

    my $model = $config->{model} && blessed $config->{model} ? $config->{model} : undef;
    if ( !$model ) {
      my $class = $config->{model} // 'Yancy::Model';
      $model = $class->new(
        backend => $app->yancy->backend,
        log => $app->log,
        ( read_schema => $config->{read_schema} )x!!exists $config->{read_schema},
        schema => $config->{schema},
      );
    }
    $app->helper( 'yancy.model' => sub {
        my ( $c, $schema ) = @_;
        return $schema ? $model->schema( $schema ) : $model;
    } );

    # XXX: Add the fully-read schema back to the configuration hash.
    # This will be removed in v2.
    my @schema_names = $config->{read_schema} ? $model->schema_names : grep { !$config->{schema}{$_}{'x-ignore'} } keys %{ $config->{schema} };
    for my $schema_name ( @schema_names ) {
        my $schema = $model->schema( $schema_name );
        $schema->_check_json_schema; # In case we haven't already
        $config->{schema}{ $schema_name } = dclone( $schema->json_schema );
    }
    # XXX: Add the fully-read schema back to the backend. This should be
    # removed in favor of the backend's read_schema filling things in.
    # The backend should keep a copy of the original schema, as read
    # from the database. The model's schema can be altered.
    $app->yancy->backend->schema( $model->json_schema );

    # Resources and templates
    my $share = path( __FILE__ )->sibling( 'Yancy' )->child( 'resources' );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths }, $share->child( 'templates' )->to_string;
    push @{$app->routes->namespaces}, 'Yancy::Controller';
    push @{ $app->commands->namespaces }, 'Yancy::Command';
    $app->plugin( 'I18N', { namespace => 'Yancy::I18N' } );

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
    $app->helper( 'log_die' => \&_helper_log_die );

    # Default form is Bootstrap4. Any form plugin added after this will
    # override this one
    $app->yancy->plugin( 'Form::Bootstrap4' );
    $app->yancy->plugin( File => {
        path => $app->home->child( 'public/uploads' ),
    } );

    # Some keys we used to allow on the top level configuration, but are
    # now on the editor plugin
    my @_moved_to_editor_keys = qw( api_controller info host return_to );
    if ( my @moved_keys = grep exists $config->{$_}, @_moved_to_editor_keys ) {
        derp 'Editor configuration keys should be in the `editor` configuration hash ref: '
            . join ', ', @moved_keys;
    }

    # Add the default editor unless the user explicitly disables it
    if ( !exists $config->{editor} || defined $config->{editor} ) {
        $app->yancy->plugin( 'Editor' => {
            (
                map { $_ => $config->{ $_ } }
                grep { defined $config->{ $_ } }
                qw( openapi schema route read_schema ),
                @_moved_to_editor_keys,
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
    # XXX: This helper must be deprecated in favor of using the Model,
    # because it'd just be better to have a smaller API.
    if ( !$name ) {
        return $c->yancy->backend->schema;
    }
    if ( $schema ) {
        $c->yancy->backend->schema->{ $name } = $schema;
        return;
    }
    my $info = copy_inline_refs( $c->yancy->backend->schema, "/$name" ) || return undef;
    return keys %$info ? $info : undef;
}

sub _helper_list {
    my ( $c, $schema_name, @args ) = @_;
    my @items = @{ $c->yancy->model( $schema_name )->list( @args )->{items} };
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
    my $item = $c->yancy->model( $schema_name )->get( $id, @args );
    my $schema = $c->yancy->schema( $schema_name );
    for my $prop_name ( keys %{ $schema->{properties} } ) {
        my $prop = $schema->{properties}{ $prop_name };
        if ( $prop->{format} && $prop->{format} eq 'password' ) {
            delete $item->{ $prop_name };
        }
    }
    return $item;
}

sub _helper_delete {
    my ( $c, $schema_name, @args ) = @_;
    return $c->yancy->model( $schema_name )->delete( @args );
}

sub _helper_set {
    my ( $c, $schema, $id, $item, %opt ) = @_;
    return $c->yancy->model( $schema )->set( $id, $item );
}

sub _helper_create {
    my ( $c, $schema, $item ) = @_;

    my $props = $c->yancy->schema( $schema )->{properties};
    # XXX: We need to fix the way defaults get set: Defaults that are
    # set by the database must not be set here. See Github #124
    $item->{ $_ } = $props->{ $_ }{default}
        for grep !exists $item->{ $_ } && exists $props->{ $_ }{default},
        keys %$props;

    return $c->yancy->model( $schema )->create( $item );
}

sub _helper_validate {
    my ( $c, $schema_name, $input_item, %opt ) = @_;
    return $c->yancy->model( $schema_name )->validate( $input_item, %opt );
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

sub _helper_log_die {
    my ( $self, $class, $err ) = @_;
    # XXX: Handle JSON::Validator errors
    if ( !$err ) {
        $err = $class;
        $class = 'Mojo::Exception';
    }
    if ( !$class->can( 'new' ) ) {
        die $@ unless eval "package $class; use Mojo::Base 'Mojo::Exception'; 1";
    }
    my $e = $class->new( $err )->trace( 2 );
    $self->log->fatal( $e );
    die $e;
}

1;
