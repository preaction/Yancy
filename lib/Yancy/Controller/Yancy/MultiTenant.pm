package Yancy::Controller::Yancy::MultiTenant;
our $VERSION = '1.089';
# ABSTRACT: A controller to show a user only their content

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        schema => {
            blog => {
                properties => {
                    id => { type => 'integer' },
                    user_id => { type => 'integer' },
                    title => { type => 'string' },
                    html => { type => 'string' },
                },
            },
        },
    };

    app->routes->get( '/user/:user_id' )->to(
        'yancy-multi_tenant#list',
        schema => 'blog',
        template => 'index'
    );

    __DATA__
    @@ index.html.ep
    % for my $item ( @{ stash 'items' } ) {
        <h1><%= $item->{title} %></h1>
        <%== $item->{html} %>
    % }

=head1 DESCRIPTION

This module contains routes to manage content owned by users. When paired
with an authentication plugin like L<Yancy::Plugin::Auth::Basic>, each user
is allowed to manage their own content.

This controller extends L<Yancy::Controller::Yancy> to add filtering content
by a user's ID.

=head1 EXAMPLES

To use this controller when the URL displays a username and the content
uses an internal ID, you can use an C<under> route to map the username
in the path to the ID:

    my $user_route = app->routes->under( '/:username', sub {
        my ( $c ) = @_;
        my $username = $c->stash( 'username' );
        my @users = $c->yancy->list( user => { username => $username } );
        if ( my $user = $users[0] ) {
            $c->stash( user_id => $user->{id} );
            return 1;
        }
        return $c->reply->not_found;
    } );

    # /:username - List blog posts
    $user_route->get( '' )->to(
        'yancy-multi_tenant#list',
        schema => 'blog',
        template => 'blog_list',
    );
    # /:username/:id/:slug - Get a single blog post
    $user_route->get( '/:id/:slug' )->to(
        'yancy-multi_tenant#get',
        schema => 'blog',
        template => 'blog_view',
    );

To build a website where content is only for the current logged-in user,
combine this controller with an auth plugin like
L<Yancy::Plugin::Auth::Basic>. Use an C<under> route to set the
C<user_id> from the current user.

    app->yancy->plugin( 'Auth::Basic', {
        route => any( '' ), # All routes require login
        schema => 'user',
        username_field => 'username',
        password_digest => { type => 'SHA-1' },
    } );

    my $user_route = app->yancy->auth->route->under( '/', sub {
        my ( $c ) = @_;
        my $user = $c->yancy->auth->current_user;
        $c->stash( user_id => $user->{id} );
        return 1;
    } );

    # / - List todo items
    $user_route->get( '' )->to(
        'yancy-multi_tenant#list',
        schema => 'todo_item',
        template => 'todo_list',
    );

=head1 SEE ALSO

L<Yancy::Controller::Yancy>, L<Mojolicious::Controller>, L<Yancy>

=cut

use Mojo::Base 'Yancy::Controller::Yancy';
use Yancy::Util qw( derp );

=method list

    $routes->get( '/:user_id' )->to(
        'yancy-multi_tenant#list',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to list content owned by the given user (specified
in the C<user_id> stash value).

=head4 Input Stash

This method extends L<Yancy::Controller::Yancy/list> and adds the
following configuration and stash values:

=over

=item user_id

The ID of the user whose content should be listed. Required. Should
match a value in the C<user_id_field>.

=item user_id_field

The field in the item that holds the user ID. Defaults to C<user_id>.

=back

=cut

sub list {
    my ( $c ) = @_;
    my $user_id = $c->stash( 'user_id' ) || die "User ID not defined in stash";
    $c->stash( filter => {
        %{ $c->_resolve_filter },
        $c->stash( 'user_id_field' ) // 'user_id' => $user_id,
    } );
    return $c->SUPER::list;
}

=method get

    $routes->get( '/:user_id/:id' )->to(
        'yancy-multi_tenant#get',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to show a single item owned by a user (given by the
C<user_id> stash value).

=head4 Input Stash

This method extends L<Yancy::Controller::Yancy/get> and adds the
following configuration and stash values:

=over

=item user_id

The ID of the user whose content should be listed. Required. Should
match a value in the C<user_id_field>.

=item user_id_field

The field in the item that holds the user ID. Defaults to C<user_id>.

=back

=cut

sub get {
    my ( $c ) = @_;
    return if !$c->_is_owned_by;
    return $c->SUPER::get;
}

=method set

    $routes->any( [ 'GET', 'POST' ] => '/:id/edit' )->to(
        'yancy#set',
        schema => $schema_name,
        template => $template_name,
    );

    $routes->any( [ 'GET', 'POST' ] => '/create' )->to(
        'yancy#set',
        schema => $schema_name,
        template => $template_name,
        forward_to => $route_name,
    );

This route creates a new item or updates an existing item in
a schema. If the user is making a C<GET> request, they will simply
be shown the template. If the user is making a C<POST> or C<PUT>
request, the form parameters will be read, the data will be validated
against L<the schema configuration|Yancy::Guides::Schema>,
and the user will either be shown the form again with the
result of the form submission (success or failure) or the user will be
forwarded to another place.

This method does not authenticate users. User authentication and
authorization should be performed by an auth plugin like
L<Yancy::Plugin::Auth::Basic>.

=head4 Input Stash

This method extends L<Yancy::Controller::Yancy/set> and adds the
following configuration and stash values:

=over

=item user_id

The ID of the user whose content is being edited. Required. Will be
set in the C<user_id_field>.

=item user_id_field

The field in the item that holds the user ID. Defaults to C<user_id>.
This field will be filled in with the C<user_id> stash value.

=back

=cut

sub set {
    my ( $c ) = @_;

    # Users are not allowed to edit content from other users
    my $id = $c->stash( 'id' );
    return if $id && !$c->_is_owned_by;

    if ( $c->req->method ne 'GET' ) {
        my $user_id_field = $c->stash( 'user_id_field' ) // 'user_id';
        my $user_id = $c->stash( 'user_id' );
        if ( eval { $c->req->json } ) {
            $c->req->json->{ $user_id_field } = $user_id;
        }
        else {
            $c->req->param( $user_id_field => $c->stash( 'user_id' ) );
        }
    }

    return $c->SUPER::set;
}

=method delete

    $routes->any( [ 'GET', 'POST' ], '/delete/:id' )->to(
        'yancy#delete',
        schema => $schema_name,
        template => $template_name,
        forward_to => $route_name,
    );

This route deletes an item from a schema. If the user is making
a C<GET> request, they will simply be shown the template (which can be
used to confirm the delete). If the user is making a C<POST> or C<DELETE>
request, the item will be deleted and the user will either be shown the
form again with the result of the form submission (success or failure)
or the user will be forwarded to another place.

This method does not authenticate users. User authentication and
authorization should be performed by an auth plugin like
L<Yancy::Plugin::Auth::Basic>.

=head4 Input Stash

This method extends L<Yancy::Controller::Yancy/delete> and adds the
following configuration and stash values:

=over

=item user_id

The ID of the user whose content is being edited. Required. Will be
set in the C<user_id_field>.

=item user_id_field

The field in the item that holds the user ID. Defaults to C<user_id>.
This field will be filled in with the C<user_id> stash value.

=back

=cut

sub delete {
    my ( $c ) = @_;
    return if !$c->_is_owned_by;
    return $c->SUPER::delete;
}

# =sub _is_owned_by
#
#   return if !_is_owned_by();
#
# Check that the currently-requested item is owned by the user_id in the
# stash. This uses the schema, id, user_id, and user_id_field stash
# values. user_id_field defaults to 'user_id'. All other fields are
# required and will throw an exception if missing.
sub _is_owned_by {
    my ( $c ) = @_;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
        || die "Schema name not defined in stash";
    my $user_id = $c->stash( 'user_id' ) || die "User ID not defined in stash";
    my $schema = $c->yancy->schema( $schema_name );
    # XXX: The id_field stash is not documented and is only used by the
    # editor plugin API. We should make it so the editor API does not
    # need to use this anymore, and instead uses the x-id-field directly.
    my $id_field = $c->stash( 'id_field' ) // $schema->{'x-id-field'} // 'id';
    my $id = $c->stash( $id_field ) // die sprintf 'ID field "%s" not defined in stash', $id_field;
    my $user_id_field = $c->stash( 'user_id_field' ) // 'user_id';
    my $item = $c->yancy->backend->get( $schema_name => $id );
    if ( !$item || $item->{ $user_id_field } ne $user_id ) {
        $c->reply->not_found;
        return 0;
    }
    return 1;
}

1;
