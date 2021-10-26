package Yancy::Plugin::Auth;
our $VERSION = '1.082';
# ABSTRACT: Add one or more authentication plugins to your site

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        schema => {
            users => {
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    plugin => {
                        type => 'string',
                        enum => [qw( password token )],
                    },
                    username => { type => 'string' },
                    # Optional password for Password auth
                    password => { type => 'string' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        plugin_field => 'plugin',
        plugins => [
            [
                Password => {
                    password_digest => {
                        type => 'SHA-1',
                    },
                },
            ],
            'Token',
        ],
    } );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin adds authentication to your site.

Multiple authentication plugins can be added with this plugin. If you
only ever want to have one type of auth, you can use that auth plugin
directly if you want.

This module composes the L<Yancy::Auth::Plugin::Role::RequireUser> role
to provide the
L<require_user|Yancy::Auth::Plugin::Role::RequireUser/require_user>
authorization method.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 schema

The name of the Yancy schema that holds users. Required.

=head2 username_field

The name of the field in the schema which is the user's identifier.
This can be a user name, ID, or e-mail address, and is provided by the
user during login.

=head2 password_field

The name of the field to use for the password or secret.

=head2 plugin_field

The field to store which plugin the user is using to authenticate. This
field is only used if two auth plugins have the same username field.

=head2 plugins

An array of auth plugins to configure. Each plugin can be either a name
(in the C<Yancy::Plugin::Auth::> namespace) or an array reference with
two elements: The name (in the C<Yancy::Plugin::Auth::> namespace) and a
hash reference of configuration.

Each of this module's configuration keys will be used as the default for
all the other auth plugins. Other plugins can override this
configuration individually. For example, users and tokens can be stored
in different schemas:

    app->yancy->plugin( 'Auth' => {
        plugins => [
            [
                'Password',
                {
                    schema => 'users',
                    username_field => 'username',
                    password_field => 'password',
                    password_digest => { type => 'SHA-1' },
                },
            ],
            [
                'Token',
                {
                    schema => 'tokens',
                    token_field => 'token',
                },
            ],
        ],
    } );

=head2 Single User / Multiple Auth

To allow a single user to configure multiple authentication mechanisms, do not
configure a C<plugin_field>. Instead, give every authentication plugin its own
C<username_field>. Then, once a user has registered with one auth method, they
can log in and register with another auth method to link to the same account.

=head2 Sessions

This module uses L<Mojolicious
sessions|https://mojolicious.org/perldoc/Mojolicious/Controller#session>
to store the login information in a secure, signed cookie.

To configure the default expiration of a session, use
L<Mojolicious::Sessions
default_expiration|https://mojolicious.org/perldoc/Mojolicious/Sessions#default_expiration>.

    use Mojolicious::Lite;
    # Expire a session after 1 day of inactivity
    app->sessions->default_expiration( 24 * 60 * 60 );

=head1 HELPERS

This plugin has the following helpers.

=head2 yancy.auth.current_user

Get the current user from one of the configured plugins, if any. Returns
C<undef> if no user was found in the session.

    my $user = $c->yancy->auth->current_user
        || return $c->render( status => 401, text => 'Unauthorized' );

=head2 yancy.auth.require_user

Validate there is a logged-in user and optionally that the user data has
certain values. See L<Yancy::Plugin::Auth::Role::RequireUser/require_user>.

    # Display the user dashboard, but only to logged-in users
    my $auth_route = $app->routes->under( '/user', $app->yancy->auth->require_user );
    $auth_route->get( '' )->to( 'user#dashboard' );

=head2 yancy.auth.login_form

Return an HTML string containing the rendered login forms for all
configured auth plugins, in order.

    %# Display a login form to an unauthenticated visitor
    % if ( !$c->yancy->auth->current_user ) {
        %= $c->yancy->auth->login_form
    % }

=head2 yancy.auth.logout

Log out any current account from any auth plugin. Use this in your own
route handlers to perform a logout.

=head1 ROUTES

This plugin creates the following L<named
routes|https://mojolicious.org/perldoc/Mojolicious/Guides/Routing#Named-routes>.
Use named routes with helpers like
L<url_for|Mojolicious::Plugin::DefaultHelpers/url_for>,
L<link_to|Mojolicious::Plugin::TagHelpers/link_to>, and
L<form_for|Mojolicious::Plugin::TagHelpers/form_for>.

=head2 yancy.auth.login_form

Display all of the login forms for the configured auth plugins. This route handles C<GET>
requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.

    %= link_to Login => 'yancy.auth.login_form'
    <%= link_to 'yancy.auth.login_form', begin %>Login<% end %>
    <p>Login here: <%= url_for 'yancy.auth.login_form' %></p>

=head2 yancy.auth.logout

Log out of all configured auth plugins. This route handles C<GET>
requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.

    %= link_to Logout => 'yancy.auth.logout'
    <%= link_to 'yancy.auth.logout', begin %>Logout<% end %>
    <p>Logout here: <%= url_for 'yancy.auth.logout' %></p>

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 yancy/auth/login_form.html.ep

This displays all of the login forms for all of the configured plugins
(if the plugin has a login form).

=head2 yancy/auth/login_page.html.ep

This displays the login form on a page directing the user to log in.

=head2 layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login page, the
unauthorized error message, and other auth-related pages.

=head1 SEE ALSO

=head2 Multiplex Plugins

These are possible Auth plugins that can be used with this plugin (or as
standalone, if desired).

=over

=item * L<Yancy::Plugin::Auth::Password>

=item * L<Yancy::Plugin::Auth::Token>

=item * L<Yancy::Plugin::Auth::OAuth2>

=item * L<Yancy::Plugin::Auth::Github>

=back

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Role::Tiny::With;
with 'Yancy::Plugin::Auth::Role::RequireUser';
use Mojo::Loader qw( load_class );
use Yancy::Util qw( currym match );

has _plugins => sub { [] };
has route =>;
has logout_route =>;

sub register {
    my ( $self, $app, $config ) = @_;

    for my $plugin_conf ( @{ $config->{plugins} } ) {
        my $name;
        if ( !ref $plugin_conf ) {
            $name = $plugin_conf;
            $plugin_conf = {};
        }
        else {
            ( $name, $plugin_conf ) = @$plugin_conf;
        }

        # If we got a route config, we need to customize the plugin
        # routes as well.  If this plugin got its own "route" config,
        # use it.  Otherwise, build a route from the auth route and the
        # plugin's moniker.
        if ( my $route = $app->yancy->routify( $config->{route} ) ) {
            $plugin_conf->{route} = $app->yancy->routify(
                $plugin_conf->{route},
                $route->any( $plugin_conf->{moniker} || lc $name ),
            );
        }

        my %merged_conf = ( %$config, %$plugin_conf );
        if ( $plugin_conf->{username_field} ) {
            # If this plugin has a unique username field, we don't need
            # to specify a plugin field. This means a single user can
            # have multiple auth mechanisms.
            delete $merged_conf{ plugin_field };
        }

        my $class = join '::', 'Yancy::Plugin::Auth', $name;
        if ( my $e = load_class( $class ) ) {
            die sprintf 'Unable to load auth plugin %s: %s', $name, $e;
        }
        my $plugin = $class->new( \%merged_conf );
        push @{ $self->_plugins }, $plugin;
        # Plugin hashref overrides config from main Auth plugin
        $plugin->init( $app, \%merged_conf );
    }

    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.plugins' => currym( $self, 'plugins' ),
    );
    $app->helper(
        'yancy.auth.logout' => currym( $self, 'logout' ),
    );
    $app->helper(
        'yancy.auth.login_form' => currym( $self, 'login_form' ),
    );
    # Make this route after all the plugin routes so that it matches
    # last.
    $self->route( $app->yancy->routify(
        $config->{route},
        $app->routes->get( '/yancy/auth' ),
    ) );
    $self->logout_route(
        $self->route->get( '/logout' )->to( cb => currym( $self, '_handle_logout' ) )->name( 'yancy.auth.logout' )
    );
    $self->route->get( '' )->to( cb => currym( $self, '_login_page' ) )->name( 'yancy.auth.login_form' );
}

=method current_user

Returns the currently logged-in user, if any.

=cut

sub current_user {
    my ( $self, $c ) = @_;
    for my $plugin ( @{ $self->_plugins } ) {
        if ( my $user = $plugin->current_user( $c ) ) {
            return $user;
        }
    }
    return undef;
}

=method plugins

Returns the list of configured auth plugins.

=cut

sub plugins {
    my ( $self, $c ) = @_;
    return @{ $self->_plugins };
}

=method login_form

    %= $c->yancy->auth->login_form

Return the rendered login form template.

=cut

sub login_form {
    my ( $self, $c ) = @_;
    return $c->render_to_string(
        template => 'yancy/auth/login_form',
        plugins => $self->_plugins,
    );
}

sub _login_page {
    my ( $self, $c ) = @_;
    $c->render(
        template => 'yancy/auth/login_page',
        plugins => $self->_plugins,
    );
}

=method logout

Log out the current user. Will call the C<logout> method on all configured auth plugins.

=cut

sub logout {
    my ( $self, $c ) = @_;
    $_->logout( $c ) for $self->plugins;
}

sub _handle_logout {
    my ( $self, $c ) = @_;
    $self->logout( $c );
    $c->res->code( 303 );
    my $redirect_to = $c->param( 'redirect_to' ) // $c->req->headers->referrer // '/';
    if ( $redirect_to eq $c->req->url->path ) {
        $redirect_to = '/';
    }
    return $c->redirect_to( $redirect_to );
}

1;
