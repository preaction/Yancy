package Yancy::User;
use Mojo::Base 'Yancy::Model', -signatures;
use Scalar::Util qw( blessed );
use Mojo::JSON qw( true false );
use Mojo::Loader qw( data_section );
use Mojo::Util qw( decamelize );

=head1 DESCRIPTION

This is the user _model_: It provides user accounts, sessions, and groups.
Authentication is handled by a L<Yancy::Auth> plugin, which then use this
model to find users and set up sessions.

=cut

has _auths => sub { [] };

sub new($class, @args) {
  my $self = $class->SUPER::new(@args);
  unshift @{$self->namespaces}, 'Yancy::User';

  # Perform migrations for our backend
  # backend class minus Yancy::Backend::, lower-case.
  my ($ext) = blessed($self->backend) =~ s{Yancy::Backend::(\w+)}{\L$1}r;
  # try to find migrations.<key>
  if (my $migrations = data_section( __PACKAGE__, "migrations.$ext")) {
    # decamelize $class for migration name
    $self->backend->driver->migrations->name(decamelize(__PACKAGE__))->from_string($migrations)->migrate();
  }

  # Now that we have our database tables, we need to re-read the schema...
  $self->read_schema;

  return $self;
}

=method add_auth

Register a L<Yancy::Auth> with this model. This is called by L<Yancy::Auth>
when it is created.

=cut

sub add_auth( $self, $auth ) {
  # XXX: Make sure auth provider_name is unique!
  push @{ $self->_auths }, $auth;
}

=method auths

Returns an arrayref of the L<Yancy::Auth> objects registered with this model.

=cut

sub auths( $self ) {
  return $self->_auths;
}

=method start_session

    my $session_id = $users->start_session( $c, $user_id );

Start a new session for the given user. Creates a row in the C<sessions>
table and stores its ID in the L<Mojolicious session|Mojolicious::Controller/session>.

=cut

sub start_session( $self, $c, $user_id ) {
  my $now = _now();
  my $session_id = $self->schema('sessions')->create({
    user_id => $user_id,
    created_datetime => $now,
    last_activity_datetime => $now,
  });
  delete $c->stash->{'yancy.current_user'};
  $c->session( yancy_session_id => $session_id );
  return $session_id;
}

=method current_user

    my $user = $users->current_user( $c );

Returns the user for the current session, or C<undef> if there is no
active session.

=cut

sub current_user( $self, $c ) {
  return $c->stash->{'yancy.current_user'} //= do {
    my $session_id = $c->session('yancy_session_id');
    my $session = defined $session_id ? $self->schema('sessions')->get($session_id) : undef;
    $session && !$session->{expired_datetime}
      ? $self->schema('users')->get($session->{user_id})
      : undef;
  };
}

=method end_session

    $users->end_session( $c );

End the current session, if any.

=cut

sub end_session( $self, $c ) {
  delete $c->stash->{'yancy.current_user'};
  my $session_id = delete $c->session->{yancy_session_id} // return;
  $self->schema('sessions')->set($session_id, { expired_datetime => _now() });
  return;
}

sub _now {
  my @t = gmtime;
  return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $t[5] + 1900, $t[4] + 1, @t[3, 2, 1, 0];
}

1;
__DATA__

@@ migrations.sqlite
-- 1 up
CREATE TABLE users (
  user_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  login STRING NOT NULL,
  UNIQUE KEY (login)
);

CREATE TABLE auth_attributes (
  auth_attribute_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users (user_id),
  provider_name STRING NOT NULL,
  attribute STRING NOT NULL,
  value STRING,
  UNIQUE KEY (user_id, provider_name, attribute)
);

CREATE TABLE user_permissions (
  user_id INTEGER NOT NULL REFERENCES users (user_id),
  permission STRING,
  PRIMARY KEY (user_id, permission)
);

CREATE TABLE sessions (
  session_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  user_id STRING REFERENCES users (user_id),
  created_datetime STRING,
  last_activity_datetime STRING,
  expired_datetime STRING
);

-- 1 down
DROP TABLE sessions;
DROP TABLE user_permissions;
DROP TABLE auth_attrs;
DROP TABLE users;
