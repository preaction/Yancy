package Yancy::Plugin::Auth::Password;
our $VERSION = '1.051';
# ABSTRACT: A simple password-based auth

=encoding utf8

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        schema => {
            users => {
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string' },
                    password => { type => 'string', format => 'password' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin provides a basic password-based authentication scheme for
a site.

This module composes the L<Yancy::Auth::Plugin::Role::RequireUser> role
to provide the
L<require_user|Yancy::Auth::Plugin::Role::RequireUser/require_user>
authorization method.

=head2 Adding Users

To add the initial user (or any user), use the L<C<mojo eval>
command|Mojolicious::Command::eval>:

    ./myapp.pl eval 'yancy->create( users => { username => "dbell", password => "123qwe" } )'

This plugin adds the L</auth.digest> filter to the C<password> field, so
the password passed to C<< yancy->create >> will be properly hashed in
the database.

You can use this same technique to edit users from the command-line if
someone gets locked out:

    ./myapp.pl eval 'yancy->update( users => "dbell", { password => "123qwe" } )'

=head2 Migrate from Auth::Basic

To migrate from the deprecated L<Yancy::Plugin::Auth::Basic> module, you
should set the C<migrate_digest> config setting to the C<password_digest>
settings from your Auth::Basic configuration. If they are the same as your
current password digest settings, you don't need to do anything at all.

    # Migrate from Auth::Basic, which had SHA-1 passwords, to
    # Auth::Password using SHA-256 passwords
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        migrate_digest => {
            type => 'SHA-1',
        },
        password_digest => {
            type => 'SHA-256',
        },
    } );

    # Migrate from Auth::Basic, which had SHA-1 passwords, to
    # Auth::Password using SHA-1 passwords
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head2 Verifying Yancy Passwords in SQL (or other languages)

Passwords are stored as base64. The Perl L<Digest> module's removes the
trailing padding from a base64 string. This means that if you try to use
another method to verify passwords, you must also remove any trailing
C<=> from the base64 hash you generate.

Here are some examples for how to generate the same password hash in
different databases/languages:

* Perl:

    $ perl -MDigest -E'say Digest->new( "SHA-1" )->add( "password" )->b64digest'
    W6ph5Mm5Pz8GgiULbPgzG37mj9g

* MySQL:

    mysql> SELECT TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) );
    +--------------------------------------------------------------------+
    | TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) ) |
    +--------------------------------------------------------------------+
    | W6ph5Mm5Pz8GgiULbPgzG37mj9g                                        |
    +--------------------------------------------------------------------+

* Postgres:

    yancy=# CREATE EXTENSION pgcrypto;
    CREATE EXTENSION
    yancy=# SELECT TRIM( TRAILING '=' FROM encode( digest( 'password', 'sha1' ), 'base64' ) );
                rtrim
    -----------------------------
     W6ph5Mm5Pz8GgiULbPgzG37mj9g
    (1 row)

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 schema

The name of the Yancy schema that holds users. Required.

=head2 username_field

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
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
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

Digest information is stored with the password so that password digests
can be updated transparently when necessary. Changing the digest
configuration will result in a user's password being upgraded the next
time they log in.

=head2 allow_register

If true, allow the visitor to register their own user account.

=head2 register_fields

An array of fields to show to the user when registering an account. By
default, all required fields from the schema will be presented in the
form to register.

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

=head1 FILTERS

This module provides the following filters. See L<Yancy/Extended Field
Configuration> for how to use filters.

=head2 auth.digest

Run the field value through the configured password L<Digest> object and
store the Base64-encoded result instead.

=head1 HELPERS

This plugin has the following helpers.

=head2 yancy.auth.current_user

Get the current user from the session, if any. Returns C<undef> if no
user was found in the session.

    my $user = $c->yancy->auth->current_user
        || return $c->render( status => 401, text => 'Unauthorized' );

=head2 yancy.auth.require_user

Validate there is a logged-in user and optionally that the user data has
certain values. See L<Yancy::Plugin::Auth::Role::RequireUser/require_user>.

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

=head2 yancy.auth.password.logout

Clear the current login and allow the user to log in again.

=head2 yancy.auth.password.register_form

Display the form to register a new user, if registration is enabled.

=head2 yancy.auth.password.register

Register a new user, if registration is enabled.

=head1 TEMPLATES

To override these templates in your application, provide your own
template with the same name.

=head2 yancy/auth/password/login_form.html.ep

The form to log in.

=head2 yancy/auth/password/login_page.html.ep

The page containing the form to log in. Uses the C<login_form.html.ep>
template for the form itself.

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

=head2 yancy/auth/password/register.html.ep

The page containing the form to register a new user. Will display all of the
L</register_fields>.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Role::Tiny::With;
with 'Yancy::Plugin::Auth::Role::RequireUser';
use Yancy::Util qw( currym derp );
use Digest;

has log =>;
has schema =>;
has username_field =>;
has password_field => 'password';
has allow_register => 0;
has plugin_field => undef;
has register_fields => sub { [] };
has moniker => 'password';
has default_digest =>;
has route =>;

# The Auth::Basic digest configuration to migrate from. Auth::Basic did
# not store the digest information in the password, so we need to fix
# it.
has migrate_digest =>;

sub register {
    my ( $self, $app, $config ) = @_;
    $self->init( $app, $config );
    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.logout' => currym( $self, 'logout' ),
    );
    $app->helper(
        'yancy.auth.login_form' => currym( $self, 'login_form' ),
    );
}

sub init {
    my ( $self, $app, $config ) = @_;
    my $schema_name = $config->{schema} || $config->{collection}
        || die "Error configuring Auth::Password plugin: No schema defined\n";
    derp "'collection' configuration in Auth::Token is now 'schema'. Please fix your configuration.\n"
        if $config->{collection};
    my $schema = $app->yancy->schema( $schema_name );
    die sprintf(
        q{Error configuring Auth::Password plugin: Collection "%s" not found}."\n",
        $schema_name,
    ) unless $schema;

    $self->log( $app->log );
    $self->schema( $schema_name );
    $self->username_field( $config->{username_field} );
    $self->password_field( $config->{password_field} || 'password' );
    $self->default_digest( $config->{password_digest} );
    $self->migrate_digest( $config->{migrate_digest} );
    $self->allow_register( $config->{allow_register} );
    $self->register_fields(
        $config->{register_fields} || $app->yancy->schema( $schema_name )->{required} || []
    );
    $app->yancy->filter->add( 'yancy.plugin.auth.password' => sub {
        my ( $key, $value, $schema, @params ) = @_;
        return $self->_digest_password( $value );
    } );

    # Update the schema to digest the password correctly
    my $field = $schema->{properties}{ $self->password_field };
    push @{ $field->{ 'x-filter' } ||= [] },
        'yancy.plugin.auth.password';
    $field->{ format } = 'password';
    $app->yancy->schema( $schema_name, $schema );

    # Add fields that may not technically be required by the schema, but
    # are required for registration
    my @user_fields = (
        $self->username_field || $schema->{'x-id-field'} || 'id',
        $self->password_field,
    );
    for my $field ( @user_fields ) {
        if ( !grep { $_ eq $field } @{ $self->register_fields } ) {
            unshift @{ $self->register_fields }, $field;
        }
    }

    my $route = $app->yancy->routify( $config->{route}, '/yancy/auth/' . $self->moniker );
    $route->get( 'register' )->to( cb => currym( $self, '_get_register' ) )->name( 'yancy.auth.password.register_form' );
    $route->post( 'register' )->to( cb => currym( $self, '_post_register' ) )->name( 'yancy.auth.password.register' );
    $route->get( 'logout' )->to( cb => currym( $self, '_get_logout' ) )->name( 'yancy.auth.password.logout' );
    $route->get( '' )->to( cb => currym( $self, '_get_login' ) )->name( 'yancy.auth.password.login_form' );
    $route->post( '' )->to( cb => currym( $self, '_post_login' ) )->name( 'yancy.auth.password.login' );
    $self->route( $route );
}

sub _get_user {
    my ( $self, $c, $username ) = @_;
    my $schema_name = $self->schema;
    my $username_field = $self->username_field;
    my %search;
    if ( my $field = $self->plugin_field ) {
        $search{ $field } = $self->moniker;
    }
    if ( $username_field ) {
        $search{ $username_field } = $username;
        my ( $user ) = @{ $c->yancy->backend->list( $schema_name, \%search, { limit => 1 } )->{items} };
        return $user;
    }
    return $c->yancy->backend->get( $schema_name, $username );
}

sub _digest_password {
    my ( $self, $password ) = @_;
    my $config = $self->default_digest;
    my $digest_config_string = _build_digest_config_string( $config );
    my $digest = _get_digest_by_config_string( $digest_config_string );
    my $password_string = join '$', $digest->add( $password )->b64digest, $digest_config_string;
    return $password_string;
}

sub _set_password {
    my ( $self, $c, $username, $password ) = @_;
    my $password_string = eval { $self->_digest_password( $password ) };
    if ( $@ ) {
        $self->log->error(
            sprintf 'Error setting password for user "%s": %s', $username, $@,
        );
    }

    my $id = $self->_get_id_for_username( $c, $username );
    $c->yancy->backend->set( $self->schema, $id, { $self->password_field => $password_string } );
}

sub _get_id_for_username {
    my ( $self, $c, $username ) = @_;
    my $schema_name = $self->schema;
    my $schema = $c->yancy->schema( $schema_name );
    my $id = $username;
    my $id_field = $schema->{'x-id-field'} || 'id';
    my $username_field = $self->username_field;
    if ( $username_field && $username_field ne $id_field ) {
        $id = $self->_get_user( $c, $username )->{ $id_field };
    }
    return $id;
}

sub current_user {
    my ( $self, $c ) = @_;
    return undef unless my $session = $c->session;
    my $username = $session->{yancy}{auth}{password} or return undef;
    my $user = $self->_get_user( $c, $username );
    delete $user->{ $self->password_field };
    return $user;
}

sub login_form {
    my ( $self, $c ) = @_;
    return $c->render_to_string(
        'yancy/auth/password/login_form',
        plugin => $self,
        return_to => $c->req->param( 'return_to' ) || $c->req->headers->referrer,
    );
}

sub _get_login {
    my ( $self, $c ) = @_;
    return $c->render( 'yancy/auth/password/login_page',
        plugin => $self,
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
    return $c->render( 'yancy/auth/password/login_page',
        status => 400,
        plugin => $self,
        user => $user,
        login_failed => 1,
    );
}

sub _get_register {
    my ( $self, $c ) = @_;
    if ( !$self->allow_register ) {
        $c->app->log->error( 'Registration not allowed (set allow_register)' );
        return;
    }
    return $c->render( 'yancy/auth/password/register',
        plugin => $self,
    );
}

sub _post_register {
    my ( $self, $c ) = @_;
    if ( !$self->allow_register ) {
        $c->app->log->error( 'Registration not allowed (set allow_register)' );
        return;
    }

    my $schema_name = $self->schema;
    my $schema = $c->yancy->schema( $schema_name );
    my $username_field = $self->username_field || $schema->{'x-id-field'} || 'id';
    my $password_field = $self->password_field;

    my $username = $c->param( $username_field );
    my $pass = $c->param( $self->password_field );
    if ( $pass ne $c->param( $self->password_field . '-verify' ) ) {
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => 'password_verify',
        );
    }
    if ( $self->_get_user( $c, $username ) ) {
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => 'user_exists',
        );
    }

    # Create new user
    my $item = {
        $username_field => $username,
        $password_field => $pass,
        (
            map { $_ => $c->param( $_ ) }
            grep { !/^(?:$username_field|$password_field)$/ }
            @{ $self->register_fields }
        ),
    };
    my $id = eval { $c->yancy->create( $schema_name, $item ) };
    if ( my $exception = $@ ) {
        my $error = ref $exception eq 'ARRAY' ? 'validation' : 'create';
        $c->app->log->error( 'Error creating user: ' . $exception );
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => $error,
            exception => $exception,
        );
    }

    # Get them to log in
    $c->flash( info => 'user_created' );
    return $c->redirect_to( 'yancy.auth.password.login' );
}

sub _get_digest {
    my ( $type, @config ) = @_;
    my $digest = eval {
        Digest->new( $type, @config )
    };
    if ( my $error = $@ ) {
        if ( $error =~ m{Can't locate Digest/${type}\.pm in \@INC} ) {
            die sprintf q{Password digest type "%s" not found}."\n", $type;
        }
        die sprintf "Error loading Digest module: %s\n", $@;
    }
    return $digest;
}

sub _get_digest_by_config_string {
    my ( $config_string ) = @_;
    my @digest_parts = split /\$/, $config_string;
    return _get_digest( @digest_parts );
}

sub _build_digest_config_string {
    my ( $config ) = @_;
    my @config_parts = (
        map { $_, $config->{$_} } grep !/^type$/, keys %$config
    );
    return join '$', $config->{type}, @config_parts;
}

sub _check_pass {
    my ( $self, $c, $username, $input_password ) = @_;
    my $user = $self->_get_user( $c, $username );

    if ( !$user ) {
        $self->log->error(
            sprintf 'Error checking password for user "%s": User does not exist',
            $username
        );
        return undef;
    }

    my ( $user_password, $user_digest_config_string )
        = split /\$/, $user->{ $self->password_field }, 2;

    my $force_upgrade = 0;
    if ( !$user_digest_config_string ) {
        # This password must have come from the Auth::Basic module,
        # which did not have digest configuration stored with the
        # password. So, we need to know what kind of digest to use, and
        # we need to fix the password.
        $user_digest_config_string = _build_digest_config_string(
            $self->migrate_digest || $self->default_digest
        );
        $force_upgrade = 1;
    }

    my $digest = eval { _get_digest_by_config_string( $user_digest_config_string ) };
    if ( $@ ) {
        die sprintf 'Error checking password for user "%s": %s', $username, $@;
    }
    my $check_password = $digest->add( $input_password )->b64digest;

    my $success = $check_password eq $user_password;

    my $default_config_string = _build_digest_config_string( $self->default_digest );
    if ( $success && ( $force_upgrade || $user_digest_config_string ne $default_config_string ) ) {
        # We need to re-create the user's password field using the new
        # settings
        $self->_set_password( $c, $username, $input_password );
    }

    return $success;
}

sub logout {
    my ( $self, $c ) = @_;
    delete $c->session->{yancy}{auth}{password};
}

sub _get_logout {
    my ( $self, $c ) = @_;
    $self->logout( $c );
    $c->flash( info => 'logout' );
    return $c->redirect_to( 'yancy.auth.password.login_form' );
}

1;

