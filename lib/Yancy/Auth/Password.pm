package Yancy::Auth::Password;
our $VERSION = '1.089';
# ABSTRACT: A simple password-based auth

=encoding utf8

=head1 SYNOPSIS

    use Yancy::Auth::Password;
    my $auth = Yancy::Auth::Password->new( $app,
      model => $model, # A Yancy::User object
    );

=head1 DESCRIPTION

This plugin provides a basic password-based authentication scheme for
a site.

Passwords are hashed with L<Crypt::Passphrase>, using Argon2id by default.
Each hash has its own random salt, and the hash settings are stored with the
hash, so they can be changed later.

=head2 Adding Users

XXX

=head2 Upgrading Passwords

Passwords hashed with an older L<Digest> configuration (C<base64$Type>, as
created by earlier versions of Yancy) can still be used to log in. When
a user logs in with a password whose hash does not match the current
L</passphrase> settings, the password is hashed again with the current
settings.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 passphrase

The L<Crypt::Passphrase> configuration used to hash new passwords, given as
the C<encoder> to L<Crypt::Passphrase/new>. Defaults to Argon2id using the
C<interactive> profile:

    passphrase => { module => 'Argon2', profile => 'interactive' },

Any L<Crypt::Passphrase> encoder can be used, like
L<Crypt::Passphrase::Bcrypt>:

    passphrase => { module => 'Bcrypt', cost => 12 },

=head2 digest

B<Removed.> Passwords are now hashed with L</passphrase>. Existing
L<Digest> hashes are still accepted and upgraded when the user logs in.

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 auth/password.html.ep

The form to log in.

=head1 SEE ALSO

L<Yancy::Auth>, L<Yancy::User>, L<Crypt::Passphrase>

=cut

use Mojo::Base 'Yancy::Auth', -signatures;
use Yancy::Util qw( currym routify );
use Digest;
use Crypt::Passphrase;
use Crypt::Passphrase::Fallback;
use Crypt::Passphrase::Validator;

has provider_name => 'password';
has template => 'auth/password';
has layout => 'auth';
has passphrase => sub { { module => 'Argon2', profile => 'interactive' } };
has _passphrase => sub ($self) {
    return Crypt::Passphrase->new(
        encoder => $self->passphrase,
        validators => [
            # Hashes from the old Digest configuration: "base64$Type[$key$value...]"
            Crypt::Passphrase::Fallback->new(
                acceptor => sub ($hash) { $hash =~ m{^[A-Za-z0-9+/]+\$[A-Za-z]} },
                callback => \&_check_digest_password,
            ),
        ],
    );
};
# Checked when the login does not exist, so a failed login takes about the
# same time whether or not the login exists
has _dummy_hash => sub ($self) { $self->_passphrase->hash_password( 'yancy' ) };

sub new($class, $app, @args) {
    my $self = $class->SUPER::new($app, @args);
    if ( $self->{digest} ) {
        $self->log->warn(
            'Yancy::Auth::Password `digest` is no longer used. Passwords are hashed with `passphrase`',
        );
    }

    my $route = routify( $app, $self->route );
    $route->get( '' )->to( cb => currym( $self, '_get_login' ) )->name( $self->route_name('entrypoint') );
    $route->post( '' )->to( cb => currym( $self, '_post_login' ) )->name( $self->route_name('login') );

    return $self;
}

sub set_password( $self, $login, $password ) {
    my $user = $self->get_user( $login );
    my $password_string = eval { $self->_passphrase->hash_password( $password ) };
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

# Verify a password against a hash from the old Digest configuration
sub _check_digest_password( $password, $stored_password ) {
    my ( $user_password, $user_digest_config_string ) = split /\$/, $stored_password, 2;
    my $digest = eval { _get_digest_by_config_string( $user_digest_config_string ) }
        or return 0;
    my $check_password = $digest->add( $password )->b64digest;
    return Crypt::Passphrase::Validator->secure_compare( $check_password, $user_password );
}

sub _check_pass($self, $c, $login, $input_password) {
    my $passphrase = $self->_passphrase;
    my $user = $self->get_user( $login );
    if ( !$user ) {
        $passphrase->verify_password( $input_password // '', $self->_dummy_hash );
        return undef;
    }

    my $stored_password = $self->attribute( $user->{user_id}, 'password' );
    if ( !$stored_password ) {
        $self->log->error(
            sprintf 'Error checking password for user "%s": No stored password',
            $login,
        );
        return undef;
    }

    my $success = $passphrase->verify_password( $input_password // '', $stored_password );
    if ( $success && $passphrase->needs_rehash( $stored_password ) ) {
        # Re-hash the user's password using the current settings
        $self->set_password( $login, $input_password );
    }

    return $success;
}
1;
