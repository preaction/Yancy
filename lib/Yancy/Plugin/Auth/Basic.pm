package Yancy::Plugin::Auth::Basic;
our $VERSION = '0.018';
# ABSTRACT: A simple auth module for a site

=encoding utf8
=head1 SYNOPSIS

    # myapp.pl
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://localhost/mysite',
        collections => {
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
    plugin 'Auth::Basic' => {
        collection => 'users',
        username_field => 'username',
        password_field => 'password', # default
        password_digest => {
            type => 'SHA-1',
        },
    };

    # yancy.conf
    {
        backend => 'pg://localhost/mysite',
        collections => {
            users => {
                required => [ 'username', 'password' ],
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    username => { type => 'string' },
                    password => { type => 'string', format => 'password' },
                },
            },
        },
        plugins => [
            [
                'Auth::Basic', {
                    collection => 'users',
                    username_field => 'username',
                    password_field => 'password', # default
                    password_digest => {
                        type => 'SHA-1',
                    },
                },
            ],
        ],
    }


=head1 DESCRIPTION

This plugin provides a basic authentication and authorization scheme for
a L<Mojolicious> site using L<Yancy>. If a user is authenticated, they are
then authorized to use the administration application and API.

=head1 CONFIGURATION

This plugin has the following configuration options.

=over

=item collection

The name of the Yancy collection that holds users. Required.

=item username_field

The name of the field in the collection which is the user's identifier.
This can be a user name, ID, or e-mail address, and is provided by the
user during login.

This field is optional. If not specified, the collection's ID field will
be used. For example, if the collection uses the C<username> field for its
primary key, we don't need to provide a C<username_field>.

    plugin Yancy => {
        collections => {
            users => {
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string' },
                    password => { type => 'string' },
                },
            },
        },
    };
    plugin 'Auth::Basic' => {
        collection => 'users',
        password_digest => { type => 'SHA-1' },
    };

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
    plugin 'Auth::Basic' => {
        password_digest => {
            type => 'Bcrypt',
            cost => 12,
            salt => 'abcdefgh♥stuff',
        },
    };

=item route

The root route that this auth module should protect. Defaults to
protecting only the Yancy editor application.

=back

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

=head1 SUBCLASSING AND CUSTOM AUTH

This class is intended to be extended for custom authentication modules.
You can replace any of the templates or helpers (above) that you need
after calling this class's C<register> method.

If this API is not enough to implement your authentication module,
please let me know and we can add a solution. If all authentication
modules have the same API, it will be better for users.

=head1 SEE ALSO

L<Digest>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Digest;

sub register {
    my ( $self, $app, $config ) = @_;
    # Prepare and validate backend data configuration
    my $coll = $config->{collection};
    my $username_field = $config->{username_field};
    my $password_field = $config->{password_field} || 'password';
    my $digest = Digest->new( delete $config->{password_digest}{type}, %{ $config->{password_digest} } );
    $app->yancy->filter->add( 'auth.digest' => sub {
        my ( $name, $value, $field ) = @_;
        return $digest->add( $value )->b64digest;
    } );
    push @{ $app->yancy->config->{collections}{$coll}{properties}{$password_field}{'x-filter'} }, 'auth.digest';

    # Add authentication check
    my $route = $config->{route} || $app->yancy->route;
    my $auth_route = $route->under( sub {
        my ( $c ) = @_;
        # Check auth
        return 1 if $c->yancy->auth->current_user;
        # Render some unauthorized result
        if ( grep { $_ eq 'api' } @{ $c->req->url->path } ) {
            # Render JSON unauthorized response
            $c->render( status => 401, openapi => {
                message => 'You are not authorized to view this page. Please log in.',
            } );
            return;
        }
        else {
            # Render HTML response
            $c->render( status => 401, template => 'yancy/auth/unauthorized' );
            return;
        }
    } );
    my @routes = @{ $route->children }; # Loop over copy while we modify original
    for my $r ( @routes ) {
        next if $r eq $auth_route; # Can't reparent ourselves or route disappears
        $auth_route->add_child( $r );
    }
    $app->helper( 'yancy.auth.route' => sub { $auth_route } );

    # Add auth helpers
    $app->helper( 'yancy.auth.get_user' => sub {
        my ( $c, $username ) = @_;
        return $username_field
            ? $c->yancy->backend->list( $coll, { $username_field => $username }, { limit => 1 } )->{rows}[0]
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
        my $check_pass = $digest->add( $pass )->b64digest;
        return $user->{ $password_field } eq $check_pass;
    } );
    $app->helper( 'yancy.auth.clear' => sub {
        my ( $c ) = @_;
        delete $c->session->{ username };
    } );

    # Add login pages
    push @{ $app->renderer->classes }, __PACKAGE__;
    $route->get( '/login' )->to( cb => \&_get_login )->name( 'yancy.login_form' );
    $route->post( '/login' )->to( cb => \&_post_login )->name( 'yancy.check_login' );
    $route->get( '/logout' )->to( cb => \&_get_logout )->name( 'yancy.logout' );
}

sub _get_login {
    my ( $c ) = @_;
    return $c->render( 'yancy/auth/login' );
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
    return $c->render( 'yancy/auth/login', status => 400 );
}

sub _get_logout {
    my ( $c ) = @_;
    $c->yancy->auth->clear;
    $c->flash( info => 'Logged out' );
    return $c->render( 'yancy/auth/login' );
}

1;
__DATA__
@@ yancy/auth/login.html.ep
% layout 'yancy';
<main id="app" class="container-fluid" style="margin-top: 10px">
    <div class="row justify-content-md-center">
        <div class="col-md-4">
            <h1>Login</h1>
            <form action="<%= url_for 'yancy.check_login' %>" method="POST">
                <input type="hidden" name="return_to" value="<%= $c->req->headers->referrer %>" />
                <div class="form-group">
                    <label for="yancy-username">Username</label>
                    <input class="form-control" id="yancy-username" name="username" placeholder="username">
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

@@ yancy/auth/unauthorized.html.ep
% layout 'yancy';
<main class="container-fluid" style="margin-top: 10px">
    <div class="row">
        <div class="col">
            <h1>Unauthorized</h1>
            <p>You are not authorized to view this page. <a href="<%= url_for
            'yancy.login_form' %>">Please log in</a></p>
        </div>
    </div>
</main>

