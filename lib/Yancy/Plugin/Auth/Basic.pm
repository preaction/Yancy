package Yancy::Plugin::Auth::Basic;
our $VERSION = '1.076';
# ABSTRACT: (DEPRECATED) A simple auth module for a site

=encoding utf8

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://localhost/mysite',
        schema => {
            users => {
                required => [ 'username', 'password' ],
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    username => { type => 'string' },
                    password => { type => 'string', format => 'password' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Basic' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head1 DESCRIPTION

B<NOTE>: This plugin is deprecated and will be removed in Yancy v2.000. Please
switch to the new pluggable auth L<Yancy::Plugin::Auth> or the new password
auth L<Yancy::Plugin::Auth::Password>.

This plugin provides a basic authentication and authorization scheme for
a L<Mojolicious> site using L<Yancy>. If a user is authenticated, they are
then authorized to use the administration application and API.

=head1 CONFIGURATION

This plugin has the following configuration options.

=over

=item schema

The name of the Yancy schema that holds users. Required.

=item username_field

The name of the field in the schema which is the user's identifier.
This can be a user name, ID, or e-mail address, and is provided by the
user during login.

This field is optional. If not specified, the schema's ID field will
be used. For example, if the schema uses the C<username> field as
a unique identifier, we don't need to provide a C<username_field>.

    plugin Yancy => {
        schema => {
            users => {
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string' },
                    password => { type => 'string' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Basic' => {
        schema => 'users',
        password_digest => { type => 'SHA-1' },
    } );

=item password_field

The name of the field to use for the user's password. Defaults to C<password>.

This field will automatically be set up to use the L</auth.digest> filter to
properly hash the password when updating it.

=item password_digest

This is the hashing mechanism that should be used for passwords. There is no
default, so you must configure one.

This value should be a hash of digest configuration. The one required
field is C<type>, and should be a type supported by the L<Digest> module:

=over

=item * MD5 (part of core Perl)

=item * SHA-1 (part of core Perl)

=item * SHA-256 (part of core Perl)

=item * SHA-512 (part of core Perl)

=item * Bcrypt (recommended)

=back

Additional fields are given as configuration to the L<Digest> module.
Not all Digest types require additional configuration.

    # Use Bcrypt for passwords
    # Install the Digest::Bcrypt module first!
    app->yancy->plugin( 'Auth::Basic' => {
        password_digest => {
            type => 'Bcrypt',
            cost => 12,
            salt => 'abcdefgh♥stuff',
        },
    } );

=item route

The root route that this auth module should protect. Defaults to
protecting only the Yancy editor application.

=back

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

To override these templates in your application, provide your own
template with the same name.

=over

=item yancy/auth/login.html.ep

This template displays the login form. The form should have two fields,
C<username> and C<password>, and perform a C<POST> request to C<<
url_for 'yancy.check_login' >>

=item yancy/auth/unauthorized.html.ep

This template displays an error message that the user is not authorized
to view this page. This most-often appears when the user is not logged in.

=item layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login form, the
unauthorized error message, and other auth-related pages.

=back

=head1 FILTERS

This module provides the following filters. See L<Yancy/Extended Field
Configuration> for how to use filters.

=head2 auth.digest

Run the field value through the configured password L<Digest> object and
store the Base64-encoded result instead.

=head1 HELPERS

This plugin adds the following Mojolicious helpers:

=head2 yancy.auth.route

The L<route object|Mojolicious::Routes::Route> that requires
authentication.  Add your own routes as children of this route to
require authentication for your own routes.

    my $auth_route = $app->yancy->auth->route;
    $auth_route->get( '/', sub {
        my ( $c ) = @_;
        return $c->render(
            data => 'You are authorized to view this page',
        );
    } );

=head2 yancy.auth.current_user

Get/set the currently logged-in user. Returns C<undef> if no user is
logged-in.

    my $user = $c->yancy->auth->current_user
        || return $c->render( status => 401, text => 'Unauthorized' );

To set the current user, pass in the username.

    $c->yancy->auth->current_user( $username );

=head2 yancy.auth.get_user

    my $user = $c->yancy->auth->get_user( $username );

Get a user item by its C<username>.

=head2 yancy.auth.check

Check a username and password to authenticate a user. Returns true
if the user is authenticated, or returns false.

B<NOTE>: Does not change the currently logged-in user.

    if ( $c->yancy->auth->check( $username, $password ) ) {
        # Authentication succeeded
        $c->yancy->auth->current_user( $username );
    }

=head2 yancy.auth.clear

Clear the currently logged-in user (logout).

    $c->yancy->auth->clear;

=head1 SEE ALSO

L<Yancy::Plugin::Auth>, L<Digest>

=cut

use Yancy::Util qw( derp );
use Mojo::Base 'Mojolicious::Plugin';
use Digest;
use Yancy::Util qw( currym );

has logout_route =>;

sub register {
    my ( $self, $app, $config ) = @_;
    # Prepare and validate backend data configuration
    die "Error configuring Auth::Basic plugin: No password digest type defined\n"
        unless $config->{password_digest} && $config->{password_digest}{type};

    my $coll = $config->{schema} || $config->{collection}
        || die "Error configuring Auth::Basic plugin: No collection defined\n";
    die sprintf(
        q{Error configuring Auth::Basic plugin: Collection "%s" not found}."\n",
        $coll,
    ) unless $app->yancy->schema( $coll );

    derp "The Auth::Basic plugin is deprecated and will be removed in Yancy v2.000. Please migrate to the Auth::Password module.\n";

    my $username_field = $config->{username_field};
    my $password_field = $config->{password_field} || 'password';

    my $digest_type = delete $config->{password_digest}{type};
    my $digest = eval {
        Digest->new( $digest_type, %{ $config->{password_digest} } )
    };
    if ( my $error = $@ ) {
        if ( $error =~ m{Can't locate Digest/${digest_type}\.pm in \@INC} ) {
            die sprintf(
                q{Error configuring Auth::Basic plugin: Password digest type "%s" not found}."\n",
                $digest_type,
            );
        }
        die "Error configuring Auth::Basic plugin: Error loading Digest module: $@\n";
    }

    $app->yancy->filter->add( 'auth.digest' => sub {
        my ( $name, $value, $field ) = @_;
        return $digest->add( $value )->b64digest;
    } );

    # Add the password filter so editing passwords in the editor works
    my $schema = $app->yancy->schema( $coll );
    push @{ $schema->{properties}{$password_field}{'x-filter'} }, 'auth.digest';
    $app->yancy->schema( $coll, $schema );

    # Add login pages
    my $route = $config->{route} || $app->yancy->editor->route;
    push @{ $app->renderer->classes }, __PACKAGE__;
    $route->get( '/login', \&_get_login, 'yancy.login_form' );
    $route->post( '/login', \&_post_login, 'yancy.check_login' );
    $self->logout_route(
        $route->get( '/logout', \&_get_logout, 'yancy.logout' )
    );

    # Add authentication check
    my $auth_route = $route->under( sub {
        my ( $c ) = @_;
        # Check auth
        return 1 if $c->yancy->auth->current_user;
        # Render some unauthorized result
        if ( grep { $_ eq 'api' } @{ $c->req->url->path } ) {
            # Render JSON unauthorized response
            $c->render(
                handler => 'openapi', # XXX This started being necessary after Mojolicious::Plugin::OpenAPI 2.0
                status => 401,
                openapi => {
                    message => 'You are not authorized to view this page. Please log in.',
                    errors => [],
                },
            );
            return;
        }
        else {
            # Render HTML response
            $c->render( status => 401, template => 'yancy/auth/unauthorized', logout_route => $self->logout_route );
            return;
        }
    } );
    my @routes = @{ $route->children }; # Loop over copy while we modify original
    for my $r ( @routes ) {
        next if $r eq $auth_route; # Can't reparent ourselves or route disappears

        # Don't add auth to unauthed routes. We need to add the plugin's
        # routes first so that they are picked up before the `under` we
        # created, but now we're going back to add auth to all
        # previously-created routes, so we need to skip the ones that
        # must be visited by unauthed users.
        next if grep { $r->name eq $_ } qw( yancy.login_form yancy.check_login yancy.logout );

        $auth_route->add_child( $r );
    }
    $app->helper( 'yancy.auth.route' => sub { $auth_route } );

    # Add auth helpers
    $app->helper( 'yancy.auth.login_form' => currym( $self, 'login_form' ) );
    $app->helper( 'yancy.auth.get_user' => sub {
        my ( $c, $username ) = @_;
        return $username_field
            ? $c->yancy->backend->list( $coll, { $username_field => $username }, { limit => 1 } )->{items}[0]
            : $c->yancy->backend->get( $coll, $username );
    } );
    $app->helper( 'yancy.auth.current_user' => sub {
        my ( $c, $username ) = @_;
        if ( $username ) {
            $c->session( username => $username );
        }
        return if !$c->session( 'username' );
        return $c->yancy->auth->get_user( $c->session( 'username' ) );
    } );
    $app->helper( 'yancy.auth.check' => sub {
        my ( $c, $username, $pass ) = @_;
        my $user = $c->yancy->auth->get_user( $username );
        if ( !$user ) {
            $c->app->log->error(
                sprintf 'Auth failed: User "%s" does not exist.', $username,
            );
            return;
        }
        if ( !$user->{ $password_field } ) {
            $c->app->log->error(
                sprintf 'Auth failed: User "%s" password field "%s" is empty.',
                $username, $password_field,
            );
            return;
        }
        my $check_pass = $digest->add( $pass )->b64digest;
        if ( $user->{ $password_field } ne $check_pass ) {
            $c->app->log->error(
                sprintf 'Auth failed: User "%s" password is incorrect (field "%s").',
                $username, $password_field,
            );
            return;
        }
        return 1;
    } );
    $app->helper( 'yancy.auth.clear' => sub {
        my ( $c ) = @_;
        delete $c->session->{ username };
    } );

}

sub login_form {
    my ( $self, $c ) = @_;
    return $c->render_to_string( 'yancy/auth/basic/login' );
}

sub _get_login {
    my ( $c ) = @_;
    return $c->render( 'yancy/auth/basic/login',
        return_to => $c->req->headers->referrer,
    );
}

sub _post_login {
    my ( $c ) = @_;
    my $user = $c->param( 'username' );
    my $pass = $c->param( 'password' );
    if ( $c->yancy->auth->check( $user, $pass ) ) {
        $c->yancy->auth->current_user( $user );
        my $to = $c->req->param( 'return_to' ) // $c->url_for( 'yancy.index' );
        $c->res->headers->location( $to );
        return $c->rendered( 303 );
    }
    $c->flash( error => 'Username or password incorrect' );
    return $c->render( 'yancy/auth/basic/login',
        status => 400,
        user => $user,
        return_to => $c->req->param( 'return_to' ),
        login_failed => 1,
    );
}

sub _get_logout {
    my ( $c ) = @_;
    $c->yancy->auth->clear;
    $c->flash( info => 'Logged out' );
    return $c->render( 'yancy/auth/basic/login' );
}

1;
__DATA__
@@ yancy/auth/basic/login.html.ep
% layout 'yancy/auth';
<main id="app" class="container-fluid">
    <div class="row justify-content-md-center">
        <div class="col-md-4">
            <h1>Login</h1>
            % if ( stash 'login_failed' ) {
            <div class="login-error alert alert-danger" role="alert">
              Login failed: User or password incorrect!
            </div>
            % }
            <form action="<%= url_for 'yancy.check_login' %>" method="POST">
                <input type="hidden" name="return_to" value="<%= stash 'return_to' %>" />
                <div class="form-group">
                    <label for="yancy-username">Username</label>
                    <input class="form-control" id="yancy-username" name="username"
                        placeholder="username" value="<%= stash 'user' %>"
                    >
                </div>
                <div class="form-group">
                    <label for="yancy-password">Password</label>
                    <input type="password" class="form-control" id="yancy-password" name="password" placeholder="password">
                </div>
                <button class="btn btn-primary">Login</button>
            </form>
        </div>
    </div>
</main>

