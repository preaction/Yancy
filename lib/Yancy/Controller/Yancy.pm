package Yancy::Controller::Yancy;
our $VERSION = '1.085';
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

=head1 ACTION HOOKS

Every action can call one or more of your application's
L<helpers|https://mojolicious.org/perldoc/Mojolicious/Guides/Tutorial#Helpers>.
These helpers can change the item before it is displayed or
before it is saved to the database.

These helpers get one argument: An item being displayed, created, saved,
or deleted. The helper then returns the item to be displayed, created,
or saved.

    use Mojolicious::Lite -signatures;
    plugin Yancy => { ... };

    # Set a last_updated timestamp when creating or updating events
    helper update_timestamp => sub( $c, $item ) {
        $item->{last_updated} = time;
        return $item;
    };
    post '/event/:event_id' => 'yancy#set',
        {
            event_id => undef,
            schema => 'events',
            helpers => [ 'update_timestamp' ],
            forward_to => 'events.get',
        },
        'events.set';

Helpers can also be anonymous subrefs for those times when you want a
unique behavior for a single route.

    # Format the last_updated timestamp when showing event details
    use Time::Piece;
    get '/event/:event_id' => 'yancy#get',
        {
            schema => 'events',
            helpers => [
                sub( $c, $item ) {
                    $item->{last_updated} = Time::Piece->new( $item->{last_updated} );
                    return $item;
                },
            ],
        },
        'events.get';

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

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 yancy/table.html.ep

The default C<list> template. Uses the following additional stash values
for configuration:

=over

=item properties

An array reference of columns to display in the table. The same as
C<x-list-columns> in the schema configuration. Defaults to
C<x-list-columns> in the schema configuration or all of the schema's
columns in C<x-order> order. See L<Yancy::Guides::Schema/Documenting
Your Schema> for more information.

=item table

    get '/events' => (
        controller => 'yancy',
        action => 'list',
        table => {
            thead => 0, # Disable column headers
            class => 'table table-responsive', # Add a class
        },
    );

Attributes for the table tag. A hash reference of the following keys:

=over

=item thead

Whether or not to display the table head section, which contains the
column headings.  Defaults to true (C<1>). Set to false (C<0>) to
disable C<< <thead> >>.

=item show_filter

Show filter input boxes for each column in the header. Pressing C<Enter>
will filter the table.

=item id

The ID of the table element.

=item class

The class(s) of the table element.

=back

=back

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw( to_json );
use Yancy::Util qw( derp is_type );
use POSIX qw( ceil );

=method schema

Get the L<Yancy::Model::Schema> object to handle the current request. This uses
the C<schema> stash value to look up the schema from the default model. Override
the default model using the C<model> stash value.

=cut

sub schema {
  my ( $self ) = @_;
  if ( $self->stash( 'collection' ) ) {
    derp '"collection" stash key is now "schema" in controller configuration';
  }
  my $schema_name = $self->stash( 'schema' ) || $self->stash( 'collection' )
    || die "Schema name not defined in stash";
  my $model = $self->stash( 'model' ) // $self->yancy->model;
  return $model->schema( $schema_name );
}

=method item_id

Get the ID for the currently-requested item, if available, or C<undef>.

=cut

sub item_id {
  my ( $self ) = @_;
  my $id_field = $self->schema->id_field;
  if ( ref $id_field eq 'ARRAY' ) {
    my $id = { map { $_ => $self->stash( $_ ) } grep defined $self->stash( $_ ), @$id_field };
    return keys %$id == @$id_field ? $id : undef;
  }
  return $self->stash( $id_field ) // undef;
}

=method clean_item

Clean the given item by removing any sensitive fields (like passwords).

=cut

sub clean_item {
  my ( $self, $item ) = @_;
  my $props = $self->schema->json_schema->{properties};
  my @keep_props = grep { ($props->{$_}{format}//'') ne 'password' } keys %$props;
  return { map { $_ => $item->{$_} } @keep_props };
}

=method list

    $routes->get( '/' )->to(
        'yancy#list',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to list content.

=head4 Input Stash

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved. Defaults to C<yancy/table>.

=item limit

The number of items to show on the page. Defaults to C<10>.

=item page

The page number to show. Defaults to C<1>. The page number will
be used to calculate the C<offset> parameter to L<Yancy::Backend/list>.

=item filter

A hash reference of field/value pairs to filter the contents of the list
or a subref that generates this hash reference. The subref will be passed
the current controller object (C<$c>).

This overrides any query filters and so can be used to enforce
authorization / security.

=item order_by

Set the default order for the items. Supports any L<Yancy::Backend/list>
C<order_by> structure.

=item before_render

An array reference of hooks to call once for each item in the C<items> list.
See L</ACTION HOOKS> for usage.

=back

=head4 Output Stash

The following stash values are set by this method:

=over

=item items

An array reference of items to display.

=item total

The total number of items that match the given filters.

=item total_pages

The number of pages of items. Can be used for pagination.

=back

=head4 Query Params

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

=item $order_by

One or more fields to order by. Can be specified as C<< <name> >> or
C<< asc:<name> >> to sort in ascending order or C<< desc:<field> >>
to sort in descending order.

=item $match

How to match multiple field filters. Can be C<any> or C<all> (default
C<all>). C<all> means all fields must match for a row to be returned.
C<any> means at least one field must match for a row to be returned.

=item Additional Field Filters

Any named query parameter that matches a field in the schema will be
used to further filter the results. The stash C<filter> will override
this filter, so that the stash C<filter> can be used for security.

=back

=head4 Content Negotiation

If the C<GET> request accepts content type is C<application/json>, or
the URL ends in C<.json>, the results page will be returned as a JSON
object with the following keys:

=over

=item items

The array of items for this page.

=item total

The total number of results for the query.

=item offset

The current offset. Get the next page of results by increasing this
number and setting the C<$offset> query parameter.

=back

=cut

sub list {
    my ( $c ) = @_;
    my ( $filter, $opt ) = $c->_get_list_args;
    my $result = $c->schema->list( $filter, $opt );

    # XXX: Filters are deprecated
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
      || die "Schema name not defined in stash";
    $result->{items} = [
      map {
        $c->yancy->filter->apply( $schema_name, $_, 'x-filter-output' )
      }
      @{ $result->{items} }
    ];

    for my $helper ( @{ $c->stash( 'before_render' ) // [] } ) {
        $c->$helper( $_ ) for @{ $result->{items} };
    }
    $result->{items} = [ map $c->clean_item( $_ ), @{ $result->{items} } ];
    # By the time `any` is reached, the format will be blank. To support
    # any format of template, we need to restore the format stash
    my $format = $c->stash( 'format' );
    return $c->respond_to(
        json => sub {
            $c->stash( json => { %$result, offset => $opt->{offset} } );
        },
        any => sub {
            if ( !$c->stash( 'template' ) ) {
                $c->stash( template => 'yancy/table' );
            }
            $c->stash(
                ( format => $format )x!!$format,
                %$result,
                total_pages => ceil( $result->{total} / $opt->{limit} ),
            );
        },
    );
}

=method get

    $routes->get( '/:id_field' )->to(
        'yancy#get',
        schema => $schema_name,
        template => $template_name,
    );

This method is used to show a single item.

=head4 Input Stash

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item "id_field"

The ID field(s) for the item should be defined as stash items, usually via
route placeholders named after the field.

    # Schema ID field is "page_id"
    $routes->get( '/pages/:page_id' )

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item before_render

An array reference of helpers to call before the item is displayed.  See
L</ACTION HOOKS> for usage.

=back

=head4 Output Stash

The following stash values are set by this method:

=over

=item item

The item that is being displayed.

=back

=head4 Content Negotiation

If the C<GET> request accepts content type is C<application/json>, or
the URL ends in C<.json>, the item will be returned as a JSON object.

=cut

sub get {
    my ( $c ) = @_;
    my $schema = $c->schema;
    my $id = $c->item_id;
    if ( !$id ) {
      my $id_field = $schema->id_field;
      die sprintf "ID field(s) %s not defined in stash",
        join ', ', map qq("$_"), $id_field eq 'ARRAY' ? @$id_field : $id_field;
    }
    my $item = $schema->get( $id );
    if ( !$item ) {
        $c->reply->not_found;
        return;
    }

    # XXX: Filters are deprecated
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
      || die "Schema name not defined in stash";
    $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

    for my $helper ( @{ $c->stash( 'before_render' ) // [] } ) {
        $c->$helper( $item );
    }

    $item = $c->clean_item( $item );

    # By the time `any` is reached, the format will be blank. To support
    # any format of template, we need to restore the format stash
    my $format = $c->stash( 'format' );
    return $c->respond_to(
        json => sub { $c->stash( json => $item ) },
        any => sub { $c->stash( item => $item, ( format => $format )x!!$format ) },
    );
}

=method set

    # Update an existing item
    $routes->any( [ 'GET', 'POST' ] => '/:id_field/edit' )->to(
        'yancy#set',
        schema => $schema_name,
        template => $template_name,
    );

    # Create a new item
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

Displaying a form could be done as a separate route using the C<yancy#get>
method, but with more code:

    $routes->get( '/:id_field/edit' )->to(
        'yancy#get',
        schema => $schema_name,
        template => $template_name,
    );
    $routes->post( '/:id_field/edit' )->to(
        'yancy#set',
        schema => $schema_name,
        template => $template_name,
    );

=head4 Input Stash

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item "id_field"

The ID field(s) for the item should be defined as stash items, usually via
route placeholders named after the field. Optional: If not specified, a new
item will be created.

    # Schema ID field is "page_id"
    $routes->post( '/pages/:page_id' )

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item before_write

An array reference of helpers to call after the new values are applied
to the item, but before the item is written to the database. See
L</ACTION HOOKS> for usage.

=item forward_to

The name of a route to forward the user to on success. Optional. Any
route placeholders that match item field names will be filled in.

    $routes->get( '/:blog_id/:slug' )->name( 'blog.view' );
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

=head4 Output Stash

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

=head4 Query Params

This method accepts query parameters named for the fields in the schema.

Each field in the item is also set as a param using
L<Mojolicious::Controller/param> so that tag helpers like C<text_field>
will be pre-filled with the values. See
L<Mojolicious::Plugin::TagHelpers> for more information. This also means
that fields can be pre-filled with initial data or new data by using GET
query parameters.

=head4 CSRF Protection

This method is protected by L<Mojolicious's Cross-Site Request Forgery
(CSRF) protection|Mojolicious::Guides::Rendering/Cross-site request
forgery>. CSRF protection prevents other sites from tricking your users
into doing something on your site that they didn't intend, such as
editing or deleting content. You must add a C<< <%= csrf_field %> >> to
your form in order to delete an item successfully. See
L<Mojolicious::Guides::Rendering/Cross-site request forgery>.

=head4 Content Negotiation

If the C<POST> or C<PUT> request content type is C<application/json>,
the request body will be treated as a JSON object to create/set. In this
case, the form query parameters are not used.

=cut

sub set {
    my ( $c ) = @_;
    my $schema = $c->schema;
    my $id_field = $schema->id_field;
    my $id = $c->item_id;

    # Display the form, if requested. This makes the simple case of
    # displaying and managing a form easier with a single route instead
    # of two routes (one to "yancy#get" and one to "yancy#set")
    if ( $c->req->method eq 'GET' ) {
        if ( defined $id ) {
            my $item = $schema->get( $id );

            # XXX: Filters are deprecated
            my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
              || die "Schema name not defined in stash";
            $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

            $c->stash( item => $c->clean_item( $item ) );
            my $props = $schema->json_schema->{properties};
            for my $key ( keys %$props ) {
                # Mojolicious TagHelpers take current values through the
                # params, but also we allow pre-filling values through the
                # GET query parameters (except for passwords)
                next if $props->{ $key }{ format }
                    && $props->{ $key }{ format } eq 'password';
                $c->param( $key => $c->param( $key ) // $item->{ $key } );
            }
        }
        else {
            # Add an empty hashref for creating a new item
            $c->stash( item => {} );
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
            any => { },
        );
        return;
    }

    if ( $c->accepts( 'html' ) && $c->validation->csrf_protect->has_error( 'csrf_token' ) ) {
        $c->app->log->error( 'CSRF token validation failed' );
        my $item = $schema->get( $id );

        # XXX: Filters are deprecated
        my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
          || die "Schema name not defined in stash";
        $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

        $c->render(
            status => 400,
            item => $c->clean_item( $item ),
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
    my @errors;

    my $allowed_props = $c->stash( 'properties' );
    my $props = $schema->json_schema->{properties};
    for my $key ( keys %$props ) {
        if ( $allowed_props && $data->{ $key } && !grep { $_ eq $key } @$allowed_props ) {
            push @errors, {message => sprintf( 'Properties not allowed: %s.', $key ), path => '/'};
        }
        my $format = $props->{ $key }{ format } // '';
        # Password cannot be changed to an empty string
        if ( $format eq 'password' ) {
            if ( exists $data->{ $key } &&
                ( !defined $data->{ $key } || $data->{ $key } eq '' )
            ) {
                delete $data->{ $key };
            }
        }
        # Upload files
        elsif ( $format eq 'filepath' and my $upload = $c->param( $key ) ) {
            my $path = $c->yancy->file->write( $upload );
            $data->{ $key } = $path;
        }
    }
    if ( @errors ) {
        $c->res->code( 400 );
        my $item = $schema->get( $id );

        # XXX: Filters are deprecated
        my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
          || die "Schema name not defined in stash";
        $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

        $c->respond_to(
            json => { json => { errors => \@errors } },
            any => { item => $item, errors => \@errors },
        );
        return;
    }

    for my $helper ( @{ $c->stash( 'before_write' ) // [] } ) {
        $c->$helper( $data );
    }
    # ID could change during our helpers
    $id = $c->item_id;
    my $has_id = defined $id;

    # XXX: Filters are deprecated
    my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
      || die "Schema name not defined in stash";
    $data = $c->yancy->filter->apply( $schema_name, $data );

    if ( $has_id ) {
        eval { $schema->set( $id, $data ) };
        # ID field(s) may have changed
        if ( ref $id_field eq 'ARRAY' ) {
            for my $field ( @$id_field ) {
                $id->{ $field } = $data->{ $field } || $id->{ $field };
            }
        }
        else {
            $id = $data->{ $id_field } || $id;
        }
        #; $c->app->log->info( 'Set success, new id: ' . $id );
    }
    else {
        $id = eval { $schema->create( $data ) };
    }

    if ( my $errors = $@ ) {
        if ( ref $errors eq 'ARRAY' ) {
            # Validation error
            $c->res->code( 400 );
            $errors = [map {{message => $_->message, path => $_->path }} @$errors];
        }
        else {
            # Unknown error
            $c->res->code( 500 );
            $errors = [ { message => $errors } ];
        }
        my $item = $c->clean_item( $schema->get( $id ) );

        # XXX: Filters are deprecated
        my $schema_name = $c->stash( 'schema' ) || $c->stash( 'collection' )
          || die "Schema name not defined in stash";
        $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

        $c->respond_to(
            json => { json => { errors => $errors } },
            any => { item => $item, errors => $errors },
        );
        return;
    }

    my $item = $c->clean_item( $schema->get( $id ) );
    # XXX: Filters are deprecated
    $item = $c->yancy->filter->apply( $schema_name, $item, 'x-filter-output' );

    return $c->respond_to(
        json => sub {
            $c->stash(
                status => $has_id ? 200 : 201,
                json => $item,
            );
        },
        any => sub {
            if ( my $route = $c->stash( 'forward_to' ) ) {
                $c->redirect_to( $route, %$item );
                return;
            }
            $c->stash( item => $item );
        },
    );
}

=method delete

    $routes->any( [ 'GET', 'POST' ], '/delete/:id_field' )->to(
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

=head4 Input Stash

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item "id_field"

The ID field(s) for the item should be defined as stash items, usually via
route placeholders named after the field.

    # Schema ID field is "page_id"
    $routes->get( '/pages/:page_id' )

=item template

The name of the template to use. See L<Mojolicious::Guides::Rendering/Renderer>
for how template names are resolved.

=item forward_to

The name of a route to forward the user to on success. Optional.
Forwarding will not happen for JSON requests.

=item before_delete

An array reference of helpers to call just before the item is deleted.
See L</ACTION HOOKS> for usage.

=back

=head4 Output Stash

The following stash values are set by this method:

=over

=item item

The item that will be deleted. If displaying the form again after the item is deleted,
this will be C<undef>.

=back

=head4 CSRF Protection

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
    my $schema = $c->schema;
    my $id = $c->item_id;
    if ( !$id ) {
      my $id_field = $schema->id_field;
      die sprintf "ID field(s) %s not defined in stash",
        join ', ', map qq("$_"), $id_field eq 'ARRAY' ? @$id_field : $id_field;
    }

    # Display the form, if requested. This makes it easy to display
    # a confirmation page in a single route.
    if ( $c->req->method eq 'GET' ) {
        my $item = $c->clean_item( $schema->get( $id ) );
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
            any => { item => $item },
        );
        return;
    }

    if ( $c->accepts( 'html' ) && $c->validation->csrf_protect->has_error( 'csrf_token' ) ) {
        $c->app->log->error( 'CSRF token validation failed' );
        $c->render(
            status => 400,
            item => $c->clean_item( $schema->get( $id ) ),
            errors => [
                {
                    message => 'CSRF token invalid.',
                },
            ],
        );
        return;
    }

    my $item = $schema->get( $id );
    for my $helper ( @{ $c->stash( 'before_delete' ) // [] } ) {
        $c->$helper( $item );
    }
    # ID fields could change during helper
    $id = $c->item_id;
    $schema->delete( $id );

    return $c->respond_to(
        json => sub {
            $c->rendered( 204 );
            return;
        },
        any => sub {
            if ( my $route = $c->stash( 'forward_to' ) ) {
                $c->redirect_to( $route );
                return;
            }
        },
    );
}

=method feed

    $routes->websocket( '/' )->to(
        'yancy#feed',
        schema => $schema_name,
    );

Subscribe to a feed of changes to the given schema. This first sends a list result
(like L</list> would). Then it sends change messages. Change messages are JSON objects
with different fields based on the method of change:

    # An item in the list was changed
    {
        method => "set",
        # The position of the changed item in the list, 0-based
        index => 2,
        item => {
            # These are the fields that changed
            name    => 'Lars Fillmore',
        },
    }

    # An item was added to the list
    {
        method => "create",
        # The position of the new item in the list, 0-based
        index => 0,
        item => {
            # The entire, newly-created item
            # ...
        },
    }

    # An item was removed from the list. This does not necessarily mean
    # the item was removed from the database.
    {
        method => "delete",
        # The position of the item removed from the list, 0-based
        index => 0,
    }

B<TODO:> Allow the client to send change messages to the server.

=head4 Input Stash

This method uses the following stash values for configuration:

=over

=item schema

The schema to use. Required.

=item limit

The number of items to show on the page. Defaults to C<10>.

=item page

The page number to show. Defaults to C<1>. The page number will
be used to calculate the C<offset> parameter to L<Yancy::Backend/list>.

=item filter

A hash reference of field/value pairs to filter the contents of the list
or a subref that generates this hash reference. The subref will be passed
the current controller object (C<$c>).

This overrides any query filters and so can be used to enforce
authorization / security.

=item order_by

Set the default order for the items. Supports any L<Yancy::Backend/list>
C<order_by> structure.

=item before_render

An array reference of hooks to call once for each item in the C<items> list
before they are sent as messages. See L</ACTION HOOKS> for usage.

=back

=head4 Query Params

The following URL query parameters are allowed for this method:

=over

=item $page

Instead of using the C<page> stash value, you can use the C<$page> query
parameter to set the page.

=item $offset

Instead of using the C<page> stash value, you can use the C<$offset>
query parameter to set the page offset. This is overridden by the
C<$page> query parameter.

=item $limit

Instead of using the C<limit> stash value, you can use the C<$limit>
query parameter to allow users to specify their own page size.

=item $order_by

One or more fields to order by. Can be specified as C<< <name> >> or
C<< asc:<name> >> to sort in ascending order or C<< desc:<field> >>
to sort in descending order.

=item $match

How to match multiple field filters. Can be C<any> or C<all> (default
C<all>). C<all> means all fields must match for a row to be returned.
C<any> means at least one field must match for a row to be returned.

=item Additional Field Filters

Any named query parameter that matches a field in the schema will be
used to further filter the results. The stash C<filter> will override
this filter, so that the stash C<filter> can be used for security.

=back

=cut

sub feed {
    my ( $c ) = @_;
    $c->inactivity_timeout( 3600 );
    my $schema = $c->schema;

    # First, send the message for the initial page
    my ( $filter, $opt ) = $c->_get_list_args;
    my $result = $schema->list( $filter, $opt );
    for my $helper ( @{ $c->stash( 'before_render' ) // [] } ) {
        $c->$helper( $_ ) for @{ $result->{items} };
    }
    my $x_id_field = $schema->id_field;
    my @id_fields = ref $x_id_field eq 'ARRAY' ? @$x_id_field : ( $x_id_field );
    #; $c->log->debug( 'Original result: ' . $c->dumper( $result ) );
    $c->send({ json => { %$result, method => 'list' } });

    # Now, poll the database for updates every few seconds.
    # XXX: Create Yancy::Plugin::PubSub to do push messaging instead of
    # ugly polling...
    my $id = Mojo::IOLoop->recurring( $c->stash( 'interval' ) // 10, sub {
        my $new_result = $schema->list( $filter, $opt );
        #; $c->log->debug( 'New result: ' . $c->dumper( $new_result ) );
        my %seen_items;
        my @created_items;
        NEW_ITEM: for my $new_i ( 0..$#{ $new_result->{items} } ) {
            my $new_item = $new_result->{items}[$new_i];
            # Loop through the old result to find the existing items by
            # their ID fields
            for my $old_i ( 0..$#{ $result->{items} } ) {
                my $old_item = $result->{items}[$old_i];
                if ( @id_fields == grep { $new_item->{ $_ } eq $old_item->{ $_ } } @id_fields ) {
                    # Found it!
                    $seen_items{ $old_i }++;
                    my %diff =
                        map { $_ => $new_item->{ $_ } }
                        grep {; no warnings 'uninitialized'; $new_item->{ $_ } ne $old_item->{ $_ } }
                        keys %$new_item, keys %$old_item
                        ;
                    if ( keys %diff ) {
                        my $message = {
                            method => 'set',
                            index => $old_i,
                            item => \%diff,
                        };
                        #$c->log->debug( $c->dumper( $message ) );
                        $c->send({ json => $message });
                    }
                    next NEW_ITEM;
                }
            }
            # If we can't find the new item, it must have been added.
            # Queue it up to send after deletes to maintain indexes.
            push @created_items, {
                method => 'create',
                index => $new_i,
                item => $new_item,
            };
        }
        # Any items we did not see must have been removed from the list,
        # or pushed out by newly-created items. Send these in reverse to
        # maintain indexes.
        for my $old_i ( reverse grep { !$seen_items{ $_ } } 0..$#{ $result->{items} } ) {
            my $message = {
                method => 'delete',
                index => $old_i,
            };
            #$c->log->debug( $c->dumper( $message ) );
            $c->send({ json => $message });
        }
        # Now we can send the created items, from lowest index to
        # highest index
        for my $item ( @created_items ) {
            #$c->log->debug( $c->dumper( $item ) );
            $c->send({ json => $item });
        }

        $result = $new_result;
    } );
    $c->on( finish => sub { Mojo::IOLoop->remove( $id ) } );
    # XXX: Allow client to send "list" message to change the parameters
    # of the list. Respond with an entirely new result (not a diff).
    # XXX: Allow client to send "create", "set", and "delete" messages
    # to create, set, and delete items
}

sub _get_list_args {
    my ( $c ) = @_;

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
            map +{ "-" . ( $_->[1] ? $_->[0] : 'asc' ) => $_->[1] // $_->[0] },
            map +[ split /:/ ],
            split /,/, $order_by
        ];
    }
    elsif ( $order_by = $c->stash( 'order_by' ) ) {
        $opt->{order_by} = $order_by;
    }

    my $schema = $c->schema;
    my $props  = $schema->json_schema->{properties};
    my %param_filter = ();
    for my $key ( @{ $c->req->params->names } ) {
        next unless exists $props->{ $key };
        my $type = $props->{$key}{type} || 'string';
        my $value = $c->param( $key );
        if ( is_type( $type, 'string' ) ) {
            if ( ( $value =~ tr/*/%/ ) <= 0 ) {
                 $value = "\%$value\%";
            }
            $param_filter{ $key } = { -like => $value };
        }
        elsif ( grep is_type( $type, $_ ), qw(number integer) ) {
            $param_filter{ $key } = $value ;
        }
        elsif ( is_type( $type, 'boolean' ) ) {
            $param_filter{ ($value && $value ne 'false')? '-bool' : '-not_bool' } = $key;
        }
        elsif ( is_type($type, 'array') ) {
            $param_filter{ $key } = { '-has' =>  $value };
        }
        else {
            die "Sorry type '" .
                to_json( $type ) .
                "' is not handled yet, only string|number|integer|boolean|array is supported."
        }
    }
    my $filter = {
        %param_filter,
        # Stash filter always overrides param filter, for security
        %{ $c->_resolve_filter },
    };
    if ( $c->param( '$match' ) && $c->param( '$match' ) eq 'any' ) {
        $filter = [
            map +{ $_ => $filter->{ $_ } }, keys %$filter
        ];
    }

    #; use Data::Dumper;
    #; $c->app->log->info( Dumper $filter );
    #; $c->app->log->info( Dumper $opt );

    return ( $filter, $opt );
}

sub _resolve_filter {
    my ( $c ) = @_;
    my $filter = $c->stash( 'filter' );
    if ( ref $filter eq 'CODE' ) {
        return $filter->( $c );
    }
    return $filter // {};
}

1;

