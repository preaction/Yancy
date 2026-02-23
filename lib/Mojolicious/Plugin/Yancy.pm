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

=head2 yancy.model

  my $model = $c->yancy->model;
  my $schema = $c->yancy->model( $schema_name );

Return the L<Yancy::Model> or a L<Yancy::Model::Schema> by name.

=head2 yancy.form

By default, the L<Yancy::Plugin::Form::Bootstrap4> form plugin is
loaded.  You can override this with your own form plugin. See
L<Yancy::Plugin::Form> for more information.

=head2 yancy.file

By default, the L<Yancy::Plugin::File> plugin is loaded to handle file
uploading and file management. The default path for file uploads is
C<$MOJO_HOME/public/uploads>. You can override this with your own file
plugin. See L<Yancy::Plugin::File> for more information.

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
use Yancy::Util qw( load_backend curry copy_inline_refs is_type json_validator );
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
    push @{$app->routes->namespaces}, 'Yancy::Controller';
    $app->helper( 'yancy.plugin' => \&_helper_plugin );

    # XXX: Move delegated plugins to attributes of this object.
    # That allows for easier extending/replacing of them.
    # Almost everything in here should be a delegated plugin...

    # Load the model
    # XXX: This should be Yancy::Plugin::Model
    $config = { %$config };
    my $model = $config->{model} && blessed $config->{model} ? $config->{model} : undef;
    if ( !$model ) {
      my $class = $config->{model} // 'Yancy::Model';
      $model = $class->new(
        backend => $config->{backend},
        log => $app->log,
        schema => $config->{schema},
      );
    }
    $app->helper( 'yancy.model' => sub {
        my ( $c, $schema ) = @_;
        return $schema ? $model->schema( $schema ) : $model;
    } );

    # Resources and templates
    # XXX: This should be in Yancy::Plugin::Editor, since it's only the editor that uses it
    my $share = path( __FILE__ )->sibling( 'Yancy' )->child( 'resources' );
    push @{ $app->static->paths }, $share->child( 'public' )->to_string;
    push @{ $app->renderer->paths }, $share->child( 'templates' )->to_string;
    $app->plugin( 'I18N', { namespace => 'Yancy::I18N' } );

    # Helpers
    $app->helper( 'log_die' => \&_helper_log_die );

    # Default form is Bootstrap4. Any form plugin added after this will
    # override this one
    # XXX: Form and File should both be part of the content plugin
    $app->plugin( 'Yancy::Plugin::Form::Bootstrap4' );
    $app->plugin( 'Yancy::Plugin::File' => {
        path => $app->home->child( 'public/uploads' ),
    } );

    # Add the default editor unless the user explicitly disables it
    if ( !exists $config->{editor} || defined $config->{editor} ) {
        $app->plugin( 'Yancy::Plugin::Editor' => {
            %{ $config->{editor} // {} },
        } );
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

# XXX: This is kinda useless, so we should get rid of it...
sub _helper_plugin {
    my ( $c, $name, @args ) = @_;
    my $class = 'Yancy::Plugin::' . $name;
    if ( my $e = load_class( $class ) ) {
        die ref $e ? "Could not load class $class: $e" : "Could not find class $class";
    }
    my $plugin = $class->new;
    $plugin->register( $c->app, @args );
}

1;
