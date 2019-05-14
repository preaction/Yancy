package Yancy::Plugin::Auth;
our $VERSION = '1.026';
# ABSTRACT: Add one or more authentication plugins to your site

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        collections => {
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
        collection => 'users',
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

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 collection

The name of the Yancy collection that holds users. Required.

=head2 username_field

The name of the field in the collection which is the user's identifier.
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
in different collections:

    app->yancy->plugin( 'Auth' => {
        plugins => [
            [
                'Password',
                {
                    collection => 'users',
                    username_field => 'username',
                    password_field => 'password',
                    password_digest => { type => 'SHA-1' },
                },
            ],
            [
                'Token',
                {
                    collection => 'tokens',
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

=head1 TEMPLATES

=head2 yancy/auth/login.html.ep

This displays all of the login forms for all of the configured plugins
(if the plugin has a login form).

=head2 layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login form, the
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
use Mojo::Loader qw( load_class );
use Yancy::Util qw( currym match );

has _plugins => sub { [] };
has route =>;

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

        if ( $config->{route} ) {
            $plugin_conf->{route} //= $config->{route}->any( $plugin_conf->{moniker} || lc $name );
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
        'yancy.auth.require_user' => currym( $self, 'require_user' ),
    );

    $self->route( $app->routes->get( '/yancy/auth' ) );
    $self->route->to( cb => currym( $self, 'login_form' ) );
}

=method

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

=method

Returns the list of configured auth plugins.

=cut

sub plugins {
    my ( $self, $c ) = @_;
    return @{ $self->_plugins };
}

=method login_form

Render the login form template for inclusion in L<Yancy::Plugin::Auth>.

=cut

sub login_form {
    my ( $self, $c ) = @_;
    $c->render(
        template => 'yancy/auth/login',
        plugins => $self->_plugins,
    );
}

=method require_user

    my $subref = $c->yancy->auth->require_user( \%match );

Build a callback to validate there is a logged-in user, and optionally
that the current user has certain fields set. C<\%match> is optional and
is a L<SQL::Abstract where clause|SQL::Abstract/WHERE CLAUSES> matched
with L<Yancy::Util/match>.

    # Ensure the user is logged-in
    my $user_cb = $app->yancy->auth->require_user;
    my $user_only = $app->routes->under( $user_cb );

    # Ensure the user's "is_admin" field is set to 1
    my $admin_cb = $app->yancy->auth->require_user( { is_admin => 1 } );
    my $admin_only = $app->routes->under( $admin_cb );

=cut

sub require_user {
    my ( $self, $c, $where ) = @_;
    return sub {
        my ( $c ) = @_;
        #; say "Are you authorized? " . $c->yancy->auth->current_user;
        my $user = $c->yancy->auth->current_user;
        if ( !$where && $user ) {
            return 1;
        }
        if ( $where && match( $where, $user ) ) {
            return 1;
        }
        $c->stash(
            template => 'yancy/auth/unauthorized',
            status => 401,
            login_route => $self->route->render,
        );
        $c->respond_to(
            json => {},
            html => {},
        );
        return undef;
    };
}

1;
