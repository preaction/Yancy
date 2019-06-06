package Yancy::Controller::Yancy;
our $VERSION = '1.029';
# ABSTRACT: Basic controller for displaying content

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        schema => {
            blog => {
                properties => {
                    id => { type => 'integer' },
                    title => { type => 'string' },
                    html => { type => 'string' },
                },
            },
        },
    };

    app->routes->get( '/' )->to(
        'yancy#list',
        schema => 'blog',
        template => 'index',
    );

    __DATA__
    @@ index.html.ep
    % for my $item ( @{ stash 'items' } ) {
        <h1><%= $item->{title} %></h1>
        <%== $item->{html} %>
    % }

=head1 DESCRIPTION

This controller contains basic route handlers for displaying content
configured in Yancy schema. These route handlers reduce the amount
of code you need to write to display or modify your content.

Route handlers use the Mojolicious C<stash> for configuration. These values
can be set at route creation, or by an C<under> route handler.

Using these route handlers also gives you a built-in JSON API for your
website. Any user agent that requests JSON will get JSON instead of
HTML. For full details on how JSON clients are detected, see
L<Mojolicious::Guides::Rendering/Content negotiation>.

=head1 EXTENDING

Here are some tips for inheriting from this controller to add
functionality.

=over

=item set

=over

=item *

When setting field values to add to the updated/created item, use C<<
$c->req->param >> not C<< $c->param >>. The underlying code uses C<<
$c->req->param >> to get all of the params, which will not be updated if
you use C<< $c->param >>.

=back

=back

=head1 DIAGNOSTICS

=over

=item Page not found

If you get a C<404 Not Found> response or Mojolicious's "Page not found... yet!" page,
it could be from one of a few reasons:

=over

=item No route with the given path was found

Check to make sure that your routes match the URL.

=item Configured template not found

Make sure the template is configured and named correctly and the correct format
and renderer are being used.

=back

The Mojolicious debug log will have more information. Make sure you are
logging at C<debug> level by running in C<development> mode (the
default), or setting the C<MOJO_LOG_LEVEL> environment variable to
C<debug>. See L<MODE in the Mojolicious
tutorial|Mojolicious::Guides::Tutorial/Mode> for more information.

=back

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Controller';
use Yancy::Util qw( derp );

=method list

    $routes->get( '/' )->to(
        'yancy#list',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to list content.

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item limit

The number of items to show on the page. Defaults to C<10>.

=item page

The page number to show. Defaults to C<1>. The page number will
be used to calculate the C<offset> parameter to L<Yancy::Backend/list>.

=item filter

A hash reference of field/value pairs to filter the contents of the
list. This overrides any query filters and so can be used to enforce
authorization / security.

=back

The following stash values are set by this method:

=over

=item items

An array reference of items to display.

=item total_pages

The number of pages of items. Can be used for pagination.

=back

The following URL query parameters are allowed for this method:

=over

=item $page

Instead of using the C<page> stash value, you can use the C<$page> query
paremeter to set the page.

=item $offset

Instead of using the C<page> stash value, you can use the C<$offset>
query parameter to set the page offset. This is overridden by the
C<$page> query parameter.

=item $limit

Instead of using the C<limit> stash value, you can use the C<$limit>
query parameter to allow users to specify their own page size.

=item Additional Field Filters

Any named query parameter that matches a field in the schema will be
used to further filter the results. The stash C<filter> will override
this filter, so that the stash C<filter> can be used for security.

=back

=cut

sub list {
    my ( $c ) = @_;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
        || die "Schema name not defined in stash";
    my $limit = $c->param( '$limit' ) // $c->stash->{ limit } // 10;
    my $offset = $c->param( '$page' ) ? ( $c->param( '$page' ) - 1 ) * $limit
        : $c->param( '$offset' ) ? $c->param( '$offset' )
        : ( ( $c->stash->{page} // 1 ) - 1 ) * $limit;
    $c->stash( page => int( $offset / $limit ) + 1 );
    my $opt = {
        limit => $limit,
        offset => $offset,
    };

    if ( my $order_by = $c->param( '$order_by' ) ) {
        $opt->{order_by} = [
            map +{ "-$_->[0]" => $_->[1] },
            map +[ split /:/ ],
            split /,/, $order_by
        ];
    }

    my $schema = $c->yancy->schema( $schema_name )  ;
    my $props  = $schema->{properties};
    my %param_filter = ();
    for my $key ( @{ $c->req->params->names } ) {
        next unless exists $props->{ $key };
        my $type = $props->{$key}{type} || 'string';
        my $value = $c->param( $key );
        if ( _is_type( $type, 'string' ) ) {
            if ( ( $value =~ tr/*/%/ ) <= 0 ) {
                 $value = "\%$value\%";
            }
            $param_filter{ $key } = { -like => $value };
        }
        elsif ( grep _is_type( $type, $_ ), qw(number integer) ) {
            $param_filter{ $key } = $value ;
        }
        elsif ( _is_type( $type, 'boolean' ) ) {
            $param_filter{ $value ? '-bool' : '-not_bool' } = $key;
        }
        else {
            die "Sorry type '" .
                to_json( $type ) .
                "' is not handled yet, only string|number|integer|boolean is supported."
        }
    }
    my $filter = {
        %param_filter,
        # Stash filter always overrides param filter, for security
        %{ $c->stash( 'filter' ) || {} },
    };

    #; use Data::Dumper;
    #; $c->app->log->info( Dumper $filter );
    #; $c->app->log->info( Dumper $opt );

    my $items = $c->yancy->backend->list( $schema_name, $filter, $opt );
    return $c->respond_to(
        json => sub {
            $c->stash( json => { %$items, offset => $offset } );
        },
        html => sub {
            $c->stash(
                %$items,
                total_pages => int( $items->{total} / $limit ) + 1,
            );
        },
    );
}

=method get

    $routes->get( '/:id' )->to(
        'yancy#get',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to show a single item.

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item id

The ID of the item from the schema. Required. Usually part of
the route path as a placeholder.

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=back

The following stash values are set by this method:

=over

=item item

The item that is being displayed.

=back

=cut

sub get {
    my ( $c ) = @_;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
        || die "Schema name not defined in stash";
    # XXX: The id_field stash is not documented and is only used by the
    # editor plugin API. We should make it so the editor API does not
    # need to use this anymore, and instead uses the x-id-field directly.
    my $id_field = $c->stash( 'id_field' ) // 'id';
    my $id = $c->stash( $id_field ) // die sprintf 'ID field "%s" not defined in stash', $id_field;
    my $item = $c->yancy->backend->get( $schema_name => $id );
    if ( !$item ) {
        $c->reply->not_found;
        return;
    }
    return $c->respond_to(
        json => sub { $c->stash( json => $item ) },
        html => sub { $c->stash( item => $item ) },
    );
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
against L<the schema configuration|Yancy::Help::Config/Data
Schema>, and the user will either be shown the form again with the
result of the form submission (success or failure) or the user will be
forwarded to another place.

If the C<POST> or C<PUT> request content type is C<application/json>,
the request body will be treated as a JSON object to create/set. In this
case, the form query parameters are not used.

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item id

The ID of the item from the schema. Optional: If not specified, a new
item will be created. Usually part of the route path as a placeholder.

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item forward_to

The name of a route to forward the user to on success. Optional. Any
route placeholders that match item field names will be filled in.

    $routes->get( '/:id/:slug' )->name( 'blog.view' );
    $routes->post( '/create' )->to(
        'yancy#set',
        schema => 'blog',
        template => 'blog_edit.html.ep',
        forward_to => 'blog.view',
    );

    # { id => 1, slug => 'first-post' }
    # forward_to => '/1/first-post'

Forwarding will not happen for JSON requests.

=item properties

Restrict this route to only setting the given properties. An array
reference of properties to allow. Trying to set additional properties
will result in an error.

B<NOTE:> Unless restricted to certain properties using this
configuration, this method accepts all valid data configured for the
schema. The data being submitted can be more than just the fields
you make available in the form. If you do not want certain data to be
written through this form, you can prevent it by using this.

=back

The following stash values are set by this method:

=over

=item item

The item that is being edited, if the C<id> is given. Otherwise, the
item that was created.

=item errors

An array of hash references of errors that occurred during data
validation. Each hash reference is either a L<JSON::Validator::Error>
object or a hash reference with a C<message> field. See L<the
yancy.validate helper docs|Mojolicious::Plugin::Yancy/yancy.validate>
and L<JSON::Validator/validate> for more details.

=back

Each field in the item is also set as a param using
L<Mojolicious::Controller/param> so that tag helpers like C<text_field>
will be pre-filled with the values. See
L<Mojolicious::Plugin::TagHelpers> for more information. This also means
that fields can be pre-filled with initial data or new data by using GET
query parameters.

This method is protected by L<Mojolicious's Cross-Site Request Forgery
(CSRF) protection|Mojolicious::Guides::Rendering/Cross-site request
forgery>. CSRF protection prevents other sites from tricking your users
into doing something on your site that they didn't intend, such as
editing or deleting content. You must add a C<< <%= csrf_field %> >> to
your form in order to delete an item successfully. See
L<Mojolicious::Guides::Rendering/Cross-site request forgery>.

Displaying a form could be done as a separate route using the C<yancy#get>
method, but with more code:

    $routes->get( '/:id/edit' )->to(
        'yancy#get',
        schema => $schema_name,
        template => $template_name,
    );
    $routes->post( '/:id/edit' )->to(
        'yancy#set',
        schema => $schema_name,
        template => $template_name,
    );

=cut

sub set {
    my ( $c ) = @_;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
        || die "Schema name not defined in stash";
    # XXX: The id_field stash is not documented and is only used by the
    # editor plugin API. We should make it so the editor API does not
    # need to use this anymore, and instead uses the x-id-field directly.
    my $id_field = $c->stash( 'id_field' ) // 'id';
    my $id = $c->stash( $id_field );

    # Display the form, if requested. This makes the simple case of
    # displaying and managing a form easier with a single route instead
    # of two routes (one to "yancy#get" and one to "yancy#set")
    if ( $c->req->method eq 'GET' ) {
        if ( $id ) {
            my $item = $c->yancy->get( $schema_name => $id );
            $c->stash( item => $item );
            my $props = $c->yancy->schema( $schema_name )->{properties};
            for my $key ( keys %$props ) {
                # Mojolicious TagHelpers take current values through the
                # params, but also we allow pre-filling values through the
                # GET query parameters (except for passwords)
                next if $props->{ $key }{ format }
                    && $props->{ $key }{ format } eq 'password';
                $c->param( $key => $c->param( $key ) // $item->{ $key } );
            }
        }

        $c->respond_to(
            json => {
                status => 400,
                json => {
                    errors => [
                        {
                            message => 'GET request for JSON invalid',
                        },
                    ],
                },
            },
            html => { },
        );
        return;
    }

    if ( $c->accepts( 'html' ) && $c->validation->csrf_protect->has_error( 'csrf_token' ) ) {
        $c->app->log->error( 'CSRF token validation failed' );
        $c->render(
            status => 400,
            item => $c->yancy->get( $schema_name => $id ),
            errors => [
                {
                    message => 'CSRF token invalid.',
                },
            ],
        );
        return;
    }

    my $data = eval { $c->req->json } || $c->req->params->to_hash;
    delete $data->{csrf_token};
    #; use Data::Dumper;
    #; $c->app->log->debug( Dumper $data );

    my $props = $c->yancy->schema( $schema_name )->{properties};
    for my $key ( keys %$props ) {
        my $format = $props->{ $key }{ format };
        # Password cannot be changed to an empty string
        if ( $format && $format eq 'password' ) {
            if ( exists $data->{ $key } &&
                ( !defined $data->{ $key } || $data->{ $key } eq '' )
            ) {
                delete $data->{ $key };
            }
        }
    }

    my %opt;
    if ( my $props = $c->stash( 'properties' ) ) {
        $opt{ properties } = $props;
    }

    my $update = $id ? 1 : 0;
    if ( $update ) {
        eval { $c->yancy->set( $schema_name, $id, $data, %opt ) };
        # ID field may have changed
        $id = $data->{ $id_field } || $id;
        #; $c->app->log->info( 'Set success, new id: ' . $id );
    }
    else {
        $id = eval { $c->yancy->create( $schema_name, $data ) };
    }

    if ( my $errors = $@ ) {
        if ( ref $errors eq 'ARRAY' ) {
            # Validation error
            $c->res->code( 400 );
        }
        else {
            # Unknown error
            $c->res->code( 500 );
            $errors = [ { message => $errors } ];
        }
        my $item = $c->yancy->get( $schema_name, $id );
        $c->respond_to(
            json => { json => { errors => $errors } },
            html => { item => $item, errors => $errors },
        );
        return;
    }

    my $item = $c->yancy->get( $schema_name, $id );
    return $c->respond_to(
        json => sub {
            $c->stash(
                status => $update ? 200 : 201,
                json => $item,
            );
        },
        html => sub {
            if ( my $route = $c->stash( 'forward_to' ) ) {
                $c->redirect_to( $route, %$item );
                return;
            }
            $c->stash( item => $item );
        },
    );
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

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item id

The ID of the item from the schema. Required. Usually part of the
route path as a placeholder.

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item forward_to

The name of a route to forward the user to on success. Optional.
Forwarding will not happen for JSON requests.

=back

The following stash values are set by this method:

=over

=item item

The item that will be deleted. If displaying the form again after the item is deleted,
this will be C<undef>.

=back

This method is protected by L<Mojolicious's Cross-Site Request Forgery
(CSRF) protection|Mojolicious::Guides::Rendering/Cross-site request
forgery>.  CSRF protection prevents other sites from tricking your users
into doing something on your site that they didn't intend, such as
editing or deleting content.  You must add a C<< <%= csrf_field %> >> to
your form in order to delete an item successfully. See
L<Mojolicious::Guides::Rendering/Cross-site request forgery>.

=cut

sub delete {
    my ( $c ) = @_;
    if ( $c->stash( 'collection' ) ) {
        derp '"collection" stash key is now "schema" in controller configuration';
    }
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
        || die "Schema name not defined in stash";
    my $schema = $c->yancy->schema( $schema_name );
    # XXX: The id_field stash is not documented and is only used by the
    # editor plugin API. We should make it so the editor API does not
    # need to use this anymore, and instead uses the x-id-field directly.
    my $id_field = $c->stash( 'id_field' ) // $schema->{'x-id-field'} // 'id';
    my $id = $c->stash( $id_field ) // die sprintf 'ID field "%s" not defined in stash', $id_field;

    # Display the form, if requested. This makes it easy to display
    # a confirmation page in a single route.
    if ( $c->req->method eq 'GET' ) {
        my $item = $c->yancy->get( $schema_name => $id );
        $c->respond_to(
            json => {
                status => 400,
                json => {
                    errors => [
                        {
                            message => 'GET request for JSON invalid',
                        },
                    ],
                },
            },
            html => { item => $item },
        );
        return;
    }

    if ( $c->accepts( 'html' ) && $c->validation->csrf_protect->has_error( 'csrf_token' ) ) {
        $c->app->log->error( 'CSRF token validation failed' );
        $c->render(
            status => 400,
            item => $c->yancy->get( $schema_name => $id ),
            errors => [
                {
                    message => 'CSRF token invalid.',
                },
            ],
        );
        return;
    }

    $c->yancy->delete( $schema_name, $id );

    return $c->respond_to(
        json => sub {
            $c->rendered( 204 );
            return;
        },
        html => sub {
            if ( my $route = $c->stash( 'forward_to' ) ) {
                $c->redirect_to( $route );
                return;
            }
        },
    );
}

# XXX: Move this to Yancy::Util and call it 'type_in( $got, $expect )'
sub _is_type {
    my ( $type, $is_type ) = @_;
    return unless $type;
    return ref $type eq 'ARRAY'
        ? !!grep { $_ eq $is_type } @$type
        : $type eq $is_type;
}

1;

