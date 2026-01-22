package Yancy::Plugin::Editor;
our $VERSION = '1.089';
# ABSTRACT: Yancy content editor, admin, and management application

=head1 SYNOPSIS

    use Mojolicious::Lite;
    # The default editor at /yancy
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        read_schema => 1,
        editor => {
            require_user => { can_edit => 1 },
        },
    };

    # Enable another editor for blog users
    app->plugin->yancy( Editor => {
        moniker => 'blog_editor',
        backend => app->yancy->backend,
        schema => { blog_posts => app->yancy->schema( 'blog_posts' ) },
        route => app->routes->any( '/blog/editor' ),
        require_user => { can_blog => 1 },
    } );

=head1 DESCRIPTION

This plugin contains the Yancy editor application which allows editing
the data in a L<Yancy::Backend>.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 backend

The backend to use for this editor. Defaults to the default backend
configured in the L<main Yancy plugin|Mojolicious::Plugin::Yancy>.

=head2 schema

The schema to use to build the editor application. This may not
necessarily be the full and exact schema supported by the backend: You
can remove certain fields from this editor instance to protect them, for
example.

If not given, will use L<Yancy::Backend/read_schema> to read the schema
from the backend.

=head2 default_controller

The default controller for API routes. Defaults to
L<Yancy::Controller::Yancy>. Building a custom controller can allow for
customizing how the editor works and what content it displays to which
users.

=head2 moniker

The name of this editor instance. Used to build helper names and route
names.  Defaults to C<editor>. Other plugins may rely on there being
a default editor named C<editor>. Additional instances should have
different monikers.

=head2 route

A base route to add the editor to. This allows you to customize the URL
and add authentication or authorization. Defaults to allowing access to
the Yancy web application under C</yancy>, and the REST API under
C</yancy/api>.

This can be a string or a L<Mojolicious::Routes::Route> object.

=head2 return_to

The URL to use for the "Back to Application" link. Defaults to C</>.

=head2 title

The title of the page, shown in the title bar and the page header. Defaults to C<Yancy>.

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
    src="https://raw.github.com/preaction/Yancy/master/eg/doc-site/public/screenshot-custom-element.png?raw=true"
    style="width: 600px; max-width: 100%;" width="600" />

=head2 yancy.editor.route

Get the route where the editor will appear.

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 yancy/editor.html.ep

This is the main Yancy web application. You should not override this.
Instead, use the L</yancy.editor.include> helper to add new components.
If there is something you can't do using the include helper, consider
L<asking how on the Github issues board|https://github.com/preaction/Yancy/issues>
or L<filing a bug report or feature request|https://github.com/preaction/Yancy/issues>.

=head1 SEE ALSO

L<Yancy::Guides::Schema>, L<Mojolicious::Plugin::Yancy>, L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Scalar::Util qw( blessed );
use Mojo::JSON qw( true false );
use Mojo::Util qw( url_escape );
use Sys::Hostname qw( hostname );
use Yancy::Util qw( derp currym json_validator load_backend );

has moniker => 'editor';
has route =>;
has includes => sub { [] };
has menu_items => sub { +{} };
has model =>;
has schema =>;
has app => undef, weak => 1;

sub _helper_name {
    my ( $self, $name ) = @_;
    return join '.', 'yancy', $self->moniker, $name;
}

sub register {
    my ( $self, $app, $config ) = @_;

    $config->{title} //= $app->l( 'Yancy' );
    $config->{return_label} //= $app->l( 'Back to Application' );

    if ( $config->{backend} || $config->{schema} ) {
        my $backend = $config->{backend} ? (
          blessed $config->{backend} 
            ? $config->{backend}
            : load_backend( $config->{backend} )
          ) : $app->yancy->backend;
        my $model = Yancy::Model->new(
          backend => $backend,
          ( schema => $config->{schema} )x!!$config->{schema},
          ( read_schema => $config->{read_schema} )x!!exists $config->{read_schema},
        );
        $self->model( $model );
    }
    else {
        $self->model( $app->yancy->model );
    }
    $self->schema( my $schema = $config->{schema} );
    $self->app( $app );

    for my $key ( grep exists $config->{ $_ }, qw( moniker ) ) {
        $self->$key( $config->{ $key } );
    }
    $config->{default_controller} //= 'Yancy';

    # XXX: Throw an error if there is already a route here
    my $route = $app->yancy->routify( $config->{route}, '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );

    # Create authentication for editor. We need to delay fetching this
    # callback until after startup is complete so that any auth plugin
    # can be added.
    my $auth_under = sub {
        my ( $c ) = @_;
        state $auth_cb = $c->yancy->can( 'auth' )
                    && $c->yancy->auth->can( 'require_user' )
                    && $c->yancy->auth->require_user( $config->{require_user} || () );
        if ( !$auth_cb && !exists $config->{require_user} && !defined $config->{route} ) {
            $app->log->warn(
                qq{*** Cannot verify that admin editor is behind authentication.\n}
                . qq{Add a Yancy Auth plugin, add a `route` to the Yancy plugin config,\n}
                . qq{or set `editor.require_user => undef` to silence this warning\n}
            );
        }
        return $auth_cb ? $auth_cb->( $c ) : 1;
    };
    $route = $route->under( $auth_under );

    # Do some sanity checks on the config to make sure nothing bad
    # happens
    for my $schema_name ( keys %$schema ) {
        if ( my $list_cols = $schema->{ $schema_name }{ 'x-list-columns' } ) {
            for my $col ( @$list_cols ) {
                if ( ref $col eq 'HASH' ) {
                    # Check template for columns
                    my @cols = $col->{template} =~ m'\{([^{]+)\}'g;
                    if ( my ( $col ) = grep { !exists $schema->{ $schema_name }{ properties }{ $_ } } @cols ) {
                        die sprintf q{Column "%s" in x-list-columns template does not exist in schema "%s"},
                            $col, $schema_name;
                    }
                }
                else {
                    if ( !exists $schema->{ $schema_name }{ properties }{ $col } ) {
                        die sprintf q{Column "%s" in x-list-columns does not exist in schema "%s"},
                            $col, $schema_name;
                    }
                }
            }
        }
    }

    # Now create the routes and helpers the editor needs
    $route->get( '/' )->name( 'yancy.index' )
        ->to(
            template => 'yancy/index',
            controller => $config->{default_controller},
            action => 'index',
            title => $config->{title},
            return_label => $config->{return_label},
        );
    $route->post( '/upload' )->name( 'yancy.editor.upload' )
        ->to( cb => sub {
            my ( $c ) = @_;
            my $upload = $c->param( 'upload' );
            my $path = $c->yancy->file->write( $upload );
            $c->res->headers->location( $path );
            $c->render( status => 201, text => $path );
        } );
    $route->get( '/api' => { hidden => 1, format => 'json' } )->to(
        cb => sub {
            my ( $c ) = @_;
            $c->render( json => $self->model->json_schema );
        },
    );
    $route->get( '/api/:schema' => { hidden => 1, controller => 'yancy', action => 'list', model => $self->model, format => 'json' } );
    $route->post( '/api/:schema' => { hidden => 1, controller => 'yancy', action => 'set', model => $self->model, format => 'json' } );
    $route->get( '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'get', model => $self->model, format => 'json' } );
    $route->put( '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'set', model => $self->model, format => 'json' } );
    $route->any( ['DELETE'] => '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'delete', model => $self->model, format => 'json' } );

    $app->helper( $self->_helper_name( 'menu' ), currym( $self, '_helper_menu' ) );
    $app->helper( $self->_helper_name( 'include' ), currym( $self, '_helper_include' ) );
    $app->helper( $self->_helper_name( 'route' ), sub { $route } );
    $app->helper( 'yancy.route', sub {
        derp 'yancy.route helper is deprecated. Use yancy.editor.route instead';
        return $self->route;
    } );
    $self->route( $route );


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

1;
