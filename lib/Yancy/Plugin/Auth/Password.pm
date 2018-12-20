package Yancy::Plugin::Auth::Password;
our $VERSION = '1.015';
# ABSTRACT: A simple password-based auth

=encoding utf8

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        collections => {
            users => {
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    username => { type => 'string' },
                    password => { type => 'string', format => 'password' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Password' => {
        collection => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head1 DESCRIPTION

This plugin provides a basic password-based authentication scheme for
a site.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 collection

The name of the Yancy collection that holds users. Required.

=head2 username_field

The name of the field in the collection which is the user's identifier.
This can be a user name, ID, or e-mail address, and is provided by the
user during login.

This field is optional. If not specified, the collection's ID field will
be used. For example, if the collection uses the C<username> field as
a unique identifier, we don't need to provide a C<username_field>.

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
    app->yancy->plugin( 'Auth::Password' => {
        collection => 'users',
        password_digest => { type => 'SHA-1' },
    } );

=head2 password_field

The name of the field to use for the password. Defaults to C<password>.

This field will automatically be set up to use the L</auth.digest> filter to
properly hash the password when updating it.

=head2 password_digest

This is the hashing mechanism that should be used for hashing passwords.
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

There is no default: Perl core provides SHA-1 hashes, but those aren't good
enough. We recommend installing L<Digest::Bcrypt> for password hashing.

    # Use Bcrypt for passwords
    # Install the Digest::Bcrypt module first!
    app->yancy->plugin( 'Auth::Basic' => {
        password_digest => {
            type => 'Bcrypt',
            cost => 12,
            salt => 'abcdefgh♥stuff',
        },
    } );

=head1 FILTERS

This module provides the following filters. See L<Yancy/Extended Field
Configuration> for how to use filters.

=head2 auth.digest

Run the field value through the configured password L<Digest> object and
store the Base64-encoded result instead.

=head1 HELPERS

This plugin has the following helpers.

=head2 yancy.auth.current_user

Get the current user from the session, if any. Returns C<undef> if no user
was found in the session.

    my $user = $c->yancy->auth->current_user
        || return $c->render( status => 401, text => 'Unauthorized' );

=head1 ROUTES

This plugin creates the following L<named
routes|https://mojolicious.org/perldoc/Mojolicious/Guides/Routing#Named-routes>.
Use named routes with helpers like
L<url_for|Mojolicious::Plugin::DefaultHelpers/url_for>,
L<link_to|Mojolicious::Plugin::TagHelpers/link_to>, and
L<form_for|Mojolicious::Plugin::TagHelpers/form_for>.

=head2 yancy.auth.password.login_form

Display the login form. See L</TEMPLATES> below.

=head2 yancy.auth.password.login

Handle login by checking the user's username and password.

=head1 TEMPLATES

To override these templates in your application, provide your own
template with the same name.

=head2 yancy/auth/password/login.html.ep

The form to log in.

=head2 yancy/auth/unauthorized.html.ep

This template displays an error message that the user is not authorized
to view this page. This most-often appears when the user is not logged
in.

=head2 yancy/auth/unauthorized.json.ep

This template renders a JSON object with an "errors" array explaining
the error.

=head2 layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login form, the
unauthorized error message, and other auth-related pages.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy::Util qw( currym );
use Digest;

has collection =>;
has username_field =>;
has password_field =>;
has plugin_field => undef;
has moniker => 'password';
has digest =>;

sub register {
    my ( $self, $app, $config ) = @_;
    $self->init( $app, $config );
    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.check_cb' => currym( $self, 'check_cb' ),
    );
}

sub init {
    my ( $self, $app, $config ) = @_;
    my $coll = $config->{collection}
        || die "Error configuring Auth::Password plugin: No collection defined\n";
    die sprintf(
        q{Error configuring Auth::Password plugin: Collection "%s" not found}."\n",
        $coll,
    ) unless $app->yancy->schema( $coll );

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

    $self->collection( $coll );
    $self->username_field( $config->{username_field} );
    $self->password_field( $config->{password_field} || 'password' );
    $self->digest( $digest );

    my $route = $config->{route} || $app->routes->any( '/yancy/auth/password' );
    $route->get( '' )->to( cb => currym( $self, '_get_login' ) )->name( 'yancy.auth.password.login_form' );
    $route->post( '' )->to( cb => currym( $self, '_post_login' ) )->name( 'yancy.auth.password.login' );
}

sub _get_user {
    my ( $self, $c, $username ) = @_;
    my $coll = $self->collection;
    my $username_field = $self->username_field;
    my %search;
    if ( my $field = $self->plugin_field ) {
        $search{ $field } = $self->moniker;
    }
    if ( $username_field ) {
        $search{ $username_field } = $username;
        my ( $user ) = $c->yancy->list( $coll, \%search, { limit => 1 } );
        return $user;
    }
    return $c->yancy->get( $coll, $username );
}

sub current_user {
    my ( $self, $c ) = @_;
    return undef unless my $session = $c->session;
    my $username = $session->{yancy}{auth}{password} or return undef;
    return $self->_get_user( $c, $username );
}

sub login_form {
    # XXX
    return undef;
}

sub _get_login {
    my ( $self, $c ) = @_;
    return $c->render( 'yancy/auth/password/login',
        return_to => $c->req->headers->referrer,
    );
}

sub _post_login {
    my ( $self, $c ) = @_;
    my $user = $c->param( 'username' );
    my $pass = $c->param( 'password' );
    if ( $self->_check_pass( $c, $user, $pass ) ) {
        $c->session->{yancy}{auth}{password} = $user;
        my $to = $c->req->param( 'return_to' ) // '/';
        $c->res->headers->location( $to );
        return $c->rendered( 303 );
    }
    $c->flash( error => 'Username or password incorrect' );
    return $c->render( 'yancy/auth/password/login',
        status => 400,
        user => $user,
        return_to => $c->req->param( 'return_to' ),
        login_failed => 1,
    );
}

sub _check_pass {
    my ( $self, $c, $username, $password ) = @_;
    my $user = $self->_get_user( $c, $username );
    my $check_pass = $self->digest->add( $password )->b64digest;
    return $user->{ $self->password_field } eq $check_pass;
}

sub _get_logout {
    my ( $c ) = @_;
    delete $c->session->{yancy}{auth}{password};
    $c->flash( info => 'Logged out' );
    return $c->render( 'yancy/auth/password/login' );
}

sub check_cb {
    my ( $self, $c ) = @_;
    return sub {
        my ( $c ) = @_;
        $c->yancy->auth->current_user && return 1;
        $c->stash(
            template => 'yancy/auth/unauthorized',
            status => 401,
        );
        $c->respond_to(
            json => {},
            html => {},
        );
        return undef;
    };
}

1;

