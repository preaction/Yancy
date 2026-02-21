package Yancy::Auth::Password;
our $VERSION = '1.089';
# ABSTRACT: A simple password-based auth

=encoding utf8

=head1 SYNOPSIS

    use Yancy::Auth::Password;
    my $auth = Yancy::Auth::Password->new(
      model => $model, # A Yancy::User object
    )

=head1 DESCRIPTION

This plugin provides a basic password-based authentication scheme for
a site.

=head2 Adding Users

XXX

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

=head2 digest

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

Digest information is stored with the password so that password digests
can be updated transparently when necessary. Changing the digest
configuration will result in a user's password being upgraded the next
time they log in.

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 auth/password.html.ep

The form to log in.

=head1 SEE ALSO

L<Yancy::Auth>, L<Yancy::User>

=cut

use Mojo::Base 'Yancy::Auth', -signatures;
use Yancy::Util qw( currym routify );
use Digest;

has provider_name => 'password';
has template => 'auth/password';
has layout => 'auth';
has digest => sub { die 'digest is required' };

sub new($class, $app, @args) {
    my $self = $class->SUPER::new($app, @args);

    my $route = routify( $app, $self->route );
    $route->get( '' )->to( cb => currym( $self, '_get_login' ) )->name( $self->route_name('entrypoint') );
    $route->post( '' )->to( cb => currym( $self, '_post_login' ) )->name( $self->route_name('login') );

    return $self;
}

sub _digest_password( $self, $password ) {
    my $config = $self->digest;
    my $digest_config_string = _build_digest_config_string( $config );
    my $digest = _get_digest_by_config_string( $digest_config_string );
    my $password_string = join '$', $digest->add( $password )->b64digest, $digest_config_string;
    return $password_string;
}

sub set_password( $self, $login, $password ) {
    my $user = $self->get_user( $login );
    my $password_string = eval { $self->_digest_password( $password ) };
    if ( $@ ) {
        $self->log->error(
            sprintf 'Error setting password for user "%s": %s', $login, $@,
        );
        return;
    }

    $self->attribute( $user->{user_id}, password => $password_string );
}

sub url_for( $self, $c, $login='' ) {
  return $c->url_for($self->route_name('entrypoint'));
}

sub form_for( $self, $c, $login='' ) {
    return $c->render_to_string(
        $self->template,
        auth => $self,
        login => $login,
        return_to => $self->return_to($c),
    );
}

sub _get_login( $self, $c ) {
    return $c->render( $self->template,
      layout => $self->layout,
      auth => $self,
      return_to => $self->return_to($c),
    );
}

sub _post_login( $self, $c ) {
    my $login = $c->param( 'login' );
    my $pass = $c->param( 'password' );
    if ( $self->_check_pass( $c, $login, $pass ) ) {
        return $self->start_session( $c, $login );
    }
    $c->log->error('Password incorrect for ' . $login);
    $c->flash( error => 'Login or password incorrect' );
    return $c->render( $self->template,
        status => 400,
        auth => $self,
        login => $login,
        login_failed => 1,
    );
}

sub _get_digest( $type, @config ) {
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

sub _get_digest_by_config_string($config_string) {
    my @digest_parts = split /\$/, $config_string;
    return _get_digest( @digest_parts );
}

sub _build_digest_config_string($config) {
    my @config_parts = (
        map { $_, $config->{$_} } grep !/^type$/, keys %$config
    );
    return join '$', $config->{type}, @config_parts;
}

sub _check_pass($self, $c, $login, $input_password) {
    my $user = $self->get_user( $login );
    my $stored_password = $self->attribute( $user->{user_id}, 'password' );

    if ( !$stored_password ) {
        $self->log->error(
            sprintf 'Error checking password for user "%s": No stored password',
            $login,
        );
        return undef;
    }

    my ( $user_password, $user_digest_config_string )
        = split /\$/, $stored_password, 2;

    my $digest = eval { _get_digest_by_config_string( $user_digest_config_string ) };
    if ( $@ ) {
        die sprintf 'Error checking password for user "%s": %s', $login, $@;
    }
    my $check_password = $digest->add( $input_password )->b64digest;

    my $success = $check_password eq $user_password;

    my $default_config_string = _build_digest_config_string( $self->digest );
    if ( $success && ( $user_digest_config_string ne $default_config_string ) ) {
        # We need to re-create the user's password field using the new
        # settings
        $self->_set_password( $login, $input_password );
    }

    return $success;
}

1;
