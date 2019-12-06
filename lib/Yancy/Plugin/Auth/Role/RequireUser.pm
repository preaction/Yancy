package Yancy::Plugin::Auth::Role::RequireUser;
our $VERSION = '1.045';
# ABSTRACT: Add authorization based on user attributes

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => ...;

    # Require any user
    my $require_user = app->yancy->auth->require_user;
    my $user = app->routes->under( '/user', $require_user );

    # Require a user with the `is_admin` field set to true
    my $require_admin = app->yancy->auth->require_user( { is_admin => 1 } );
    my $admin = app->routes->under( '/admin', $require_admin );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin adds a simple authorization method to your site. All default
Yancy auth plugins use this role to provide the C<yancy.auth.require_user>
helper.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-role';
use Yancy::Util qw( currym match );

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

around register => sub {
    my ( $orig, $self, $app, $config ) = @_;
    $app->helper(
        'yancy.auth.require_user' => currym( $self, 'require_user' ),
    );
    $self->$orig( $app, $config );
};

1;
