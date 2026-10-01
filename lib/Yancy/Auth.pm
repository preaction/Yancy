package Yancy::Auth;
use Mojo::Base -base, -signatures;
use Scalar::Util qw( blessed );
use Mojo::JSON qw( true false );
use Mojo::Util qw( decamelize );
use Mojo::File qw( curfile );

=head1 DESCRIPTION

Each auth chooses which user is logging in.

=cut

has log => ;
has model => sub { die 'model is required' };
has provider_name => sub { die 'provider_name is required' };
has route => sub { '/auth/' . shift->provider_name };

sub new($class, $app, @args) {
  my $self = $class->SUPER::new(@args);
  $self->log($app->log);

  my $templates = curfile->sibling('Auth', 'templates');
  if (!grep { $_ eq $templates } @{$app->renderer->paths}) {
    push @{$app->renderer->paths}, "$templates";
  }

  # Auth templates use the `l` helper for translated strings
  if (!$app->renderer->get_helper('l')) {
    $app->plugin('I18N', { namespace => 'Yancy::I18N' });
  }

  # TODO: Auth sets up routes in $app

  # Add a logout route for the user model, unless another auth already did
  if ( !$app->routes->find('auth.logout') ) {
    my $model = $self->model;
    $app->routes->any( [qw( GET POST )] => '/auth/logout' )->to( cb => sub ($c) {
      $model->end_session( $c );
      my $to = $c->req->param( 'return_to' );
      $to = '/' unless $self->is_local_path( $to );
      $c->res->headers->location( $to );
      return $c->rendered( 303 );
    } )->name('auth.logout');
  }

  $self->model->add_auth( $self );
  return $self;
}

sub route_name( $self, $name ) {
  my $route_name = 'auth.' . $self->provider_name . '.' . $name;
  $self->log->debug('the route name is ' . $route_name );
  return $route_name;
}

sub url_for( $self, $c, $login ) {
  # Return how to get the user started using this authentication.
  # If $login is provided, do not make the user type it in again.

}

sub form_for( $self, $c, $login ) {
  # Return just the form, for embedding in another page.
  # If $login is provided, do not make the user type it in again.
}

=method is_local_path

    my $ok = $auth->is_local_path( $url );

Returns true if the given URL is a path on this site that is safe to redirect
to. It must start with a single C</>, and must not contain backslashes or
control characters, which browsers may treat as a C<//host> URL.
L<http://cwe.mitre.org/data/definitions/601.html>

=cut

sub is_local_path( $self, $url ) {
  return defined $url
    && $url =~ m{^/(?![/\\])}
    && $url !~ m{[\\\x00-\x1f\x7f]};
}

sub return_to( $self, $c ) {
  my $referrer = $c->req->headers->referrer;
  my ( $return_to ) = grep { $self->is_local_path( $_ ) } (
      # If we've specified one, go there directly
      $c->req->param( 'return_to' ),
      # Check flash storage, perhaps from a redirect to the login form
      $c->flash('return_to'),
      # If this is the login page, go back to referer
      ( ( $c->current_route // '' ) =~ /^auth\./ ? $referrer : () ),
      # Otherwise, return the user here
      $c->req->url->path->to_string,
  );
  return $return_to // '/';
}

sub start_session( $self, $c, $login ) {
  # Start a session for the user
  # XXX: Set last login datetime
  # XXX: Set last used provider
  # XXX: Set cookie to make auth easier next time

  # Do not allow return_to to redirect the user to another site.
  my $to = $c->req->param( 'return_to' );
  $to = '/' unless $self->is_local_path( $to );

  my $user = $self->get_user( $login )
    // die qq{Can not start session for unknown user "$login"\n};
  $self->model->start_session( $c, $user->{user_id} );

  $c->res->headers->location( $to );
  return $c->rendered( 303 );
}

sub attribute($self, $user_id, @attr) {
  my $schema = $self->model->schema('auth_attributes');
  my %props = (
    user_id => $user_id,
    provider_name => $self->provider_name,
    attribute => $attr[0],
  );
  my $res = $schema->list(\%props);

  if (@attr == 1) {
    if (!$res || !$res->{items} || !@{$res->{items}}) {
      return undef;
    }
    return $res->{items}[0]{value};
  }

  if (!$res || !$res->{items} || !@{$res->{items}}) {
    $schema->create({%props, value => $attr[1]});
  }
  else {
    $schema->set(
      $res->{items}[0]{auth_attribute_id},
      { value => $attr[1] },
    );
  }
  return;
}

sub get_user( $self, $login ) {
  my $res = $self->model->schema('users')->list({login => $login});
  if (!$res || !$res->{items} || !@{$res->{items}}) {
    return undef;
  }
  return $res->{items}[0];
}

1;
