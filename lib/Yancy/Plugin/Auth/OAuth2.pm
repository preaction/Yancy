package Yancy::Plugin::Auth::OAuth2;
our $VERSION = '1.040';
# ABSTRACT: Authenticate using an OAuth2 provider

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
    };
    app->yancy->plugin( 'Auth::OAuth2' => {
        client_id => 'CLIENT_ID',
        client_secret => 'SECRET',
        authorize_url => 'https://example.com/auth',
        token_url => 'https://example.com/token',
    } );

=head1 DESCRIPTION

This module allows authenticating using a standard OAuth2 provider by
implementing L<the OAuth2 specification|https://tools.ietf.org/html/rfc6749>.

OAuth2 provides no mechanism for transmitting any information about the
user in question, so this auth may require some customization to be
useful. Without some kind of information about the user, it is
impossible to know if this is a new user or a returning user or to
maintain any kind of account information for the user.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 client_id

The client ID, provided by the OAuth2 provider.

=head2 client_secret

The client secret, provided by the OAuth2 provider.

=head2 authorize_url

The URL to start the OAuth2 authorization process.

=head2 token_url

The URL to get an access token. The second step of the auth process.

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

=head2 layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login form, the
unauthorized error message, and other auth-related pages.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Yancy::Util qw( currym match );
use Mojo::UserAgent;
use Mojo::URL;

has ua => sub { Mojo::UserAgent->new };
has route =>;
has moniker => 'oauth2';
has client_id =>;
has client_secret =>;
has authorize_url =>;
has token_url =>;

sub register {
    my ( $self, $app, $config ) = @_;
    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.require_user' => currym( $self, 'require_user' ),
    );
    $self->init( $app, $config );
}

sub init {
    my ( $self, $app, $config ) = @_;
    for my $attr ( qw( moniker ua client_id client_secret ) ) {
        next if !$config->{ $attr };
        $self->$attr( $config->{ $attr } );
    }
    for my $url_attr ( qw( authorize_url token_url ) ) {
        next if !$config->{ $url_attr };
        $self->$url_attr( Mojo::URL->new( $config->{ $url_attr } ) );
    }
    $self->route(
        $config->{route}
        || $app->routes->any( '/yancy/auth/' . $self->moniker )
    );
    $self->route->to( cb => currym( $self, '_handle_auth' ) );
}

=method current_user

Returns the access token of the currently-logged-in user.

=cut

sub current_user {
    my ( $self, $c ) = @_;
    return $c->session->{yancy}{ $self->moniker }{access_token} || undef;
}

=method require_user

    my $subref = $c->yancy->auth->require_user;

Build a callback to validate there is a logged-in user. Since this auth
module has no information about the user, there can be no additional
authorization of the user.

=cut

sub require_user {
    my ( $self, $c ) = @_;
    return sub {
        my ( $c ) = @_;
        #; say "Are you authorized? " . $c->yancy->auth->current_user;
        my $user = $c->yancy->auth->current_user;
        if ( $user ) {
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

sub _handle_auth {
    my ( $self, $c ) = @_;

    # This sub handles both steps of authentication. If we have a code,
    # we can get a token.
    if ( my $code = $c->param( 'code' ) ) {
        my %client_info = (
            client_id => $self->client_id,
            client_secret => $self->client_secret,
            code => $code,
        );
        $self->ua->post_p( $self->token_url, form => \%client_info )
            ->then( sub {
                my ( $tx ) = @_;
                my $token = $tx->res->body_params->param( 'access_token' );
                $c->session->{yancy}{ $self->moniker }{ access_token } = $token;
                $self->handle_token_p( $c, $token )
                    ->then( sub {
                        my $return_to = $c->session->{ yancy }{ $self->moniker }{ return_to };
                        $c->redirect_to( $return_to );
                    } )
                    ->catch( sub {
                        my ( $err ) = @_;
                        $c->render( text => $err );
                    } );
            } )
            ->catch( sub {
                my ( $err ) = @_;
                $c->render(
                    text => $err,
                );
            } );
        return $c->render_later;
    }

    # If we do not have a code, we need to get one
    $c->session->{yancy}{ $self->moniker }{ return_to }
        = $c->param( 'return_to' ) || $c->req->headers->referrer;
    $c->redirect_to( $self->get_authorize_url( $c ) );
}

=method get_authorize_url

    my $url = $self->get_authorize_url( $c );

Get a full authorization URL with query parameters. Override this in
a subclass to customize the authorization parameters.

=cut

sub get_authorize_url {
    my ( $self, $c ) = @_;
    my %client_info = (
        client_id => $self->client_id,
    );
    return $self->authorize_url->clone->query( \%client_info );
}

=method handle_token_p

    my $p = $self->handle_token_p( $c, $token );

Handle the receipt of the token. Override this in a subclass to make any
API requests to identify the user. Returns a L<Mojo::Promise> that will
be fulfilled when the information is complete.

=cut

sub handle_token_p {
    my ( $self, $c, $token ) = @_;
    return Mojo::Promise->new->resolve;
}

1;
