
=head1 DESCRIPTION

This test ensures that the "MultiTenant" controller works correctly as
an API

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );

my $collections = {
    blog => {
        'x-stash-filter' => {
            # field => stash item
            user_id => 'user_id',
        },
        required => [ qw( title markdown ) ],
        properties => {
            id => { type => 'integer', readOnly => 1 },
            user_id => { type => 'integer', readOnly => 1 },
            title => { type => 'string' },
            slug => { type => 'string' },
            markdown => { type => 'string', format => 'markdown', 'x-html-field' => 'html' },
            html => { type => 'string', 'x-hidden' => 1 },
        },
    },
};
my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
    blog => [
        {
            user_id => 1,
            title => 'First Post',
            slug => 'first-post',
            markdown => '# First Post',
            html => '<h1>First Post</h1>',
        },
        {
            user_id => 2,
            title => 'Another User Post',
            slug => 'another-user-post',
            markdown => '# Another User Post',
            html => '<h1>Another User Post</h1>',
        },
        {
            user_id => 1,
            title => 'Second Post',
            slug => 'second-post',
            markdown => '# Second Post',
            html => '<h1>Second Post</h1>',
        },
    ],
);

my $USER_ID = 1;
my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->log( Mojo::Log->new );
my $top = $t->app->routes->under( '/yancy', sub {
    my ( $c ) = @_;
    $c->stash( user_id => $USER_ID );
    return 1;
} );

my $CONFIG = {
    route => $top,
    backend => $backend_url,
    api_controller => 'Yancy::MultiTenant',
    collections => $collections,
};
$t->app->plugin( 'Yancy' => $CONFIG );

subtest 'fetch generated OpenAPI spec' => sub {
    $t->get_ok( '/yancy/api' )
      ->status_is( 200 )
      ->or( sub { diag shift->tx->res->body } )
      ->content_type_like( qr{^application/json} )
      ->json_is( '/definitions/blogItem' => $CONFIG->{collections}{blog} )
      ->or( sub { diag explain shift->tx->res->json( '/definitions/blogItem' ) } )

      ->json_has( '/paths/~1blog/get/responses/200' )
      ->json_has( '/paths/~1blog/get/responses/default' )

      ->json_has( '/paths/~1blog/post/parameters' )
      ->json_has( '/paths/~1blog/post/responses/201' )
      ->json_has( '/paths/~1blog/post/responses/400' )
      ->json_has( '/paths/~1blog/post/responses/default' )

      ->json_has( '/paths/~1blog~1{id}/parameters' )
      ->json_has( '/paths/~1blog~1{id}/get/responses/200' )
      ->json_has( '/paths/~1blog~1{id}/get/responses/404' )
      ->json_has( '/paths/~1blog~1{id}/get/responses/default' )

      ->json_has( '/paths/~1blog~1{id}/put/parameters' )
      ->json_has( '/paths/~1blog~1{id}/put/responses/200' )
      ->json_has( '/paths/~1blog~1{id}/put/responses/404' )
      ->json_has( '/paths/~1blog~1{id}/put/responses/default' )

      ->json_has( '/paths/~1blog~1{id}/delete/responses/204' )
      ->json_has( '/paths/~1blog~1{id}/delete/responses/404' )
      ->json_has( '/paths/~1blog~1{id}/delete/responses/default' )
      ;
};

subtest 'fetch list' => sub {
    $t->get_ok( '/yancy/api/blog' )
      ->status_is( 200 )
      ->or( sub { diag shift->tx->res->body } )
      ->json_is( $backend->list( 'blog', { user_id => $USER_ID } ) );

    subtest 'limit/offset' => sub {
        $t->get_ok( '/yancy/api/blog?limit=1' )
          ->status_is( 200 )
          ->json_is( $backend->list( 'blog', { user_id => $USER_ID }, { limit => 1 } ) );

        $t->get_ok( '/yancy/api/blog?offset=1' )
          ->status_is( 200 )
          ->json_is( $backend->list( 'blog', { user_id => $USER_ID }, { offset => 1 } ) );
    };

    subtest 'order_by' => sub {

        $t->get_ok( '/yancy/api/blog?order_by=asc:title' )
          ->status_is( 200 )
          ->json_is( $backend->list( 'blog', { user_id => $USER_ID }, { order_by => { -asc => 'title' } } )  );

        $t->get_ok( '/yancy/api/blog?order_by=desc:title' )
          ->status_is( 200 )
          ->json_is( $backend->list( 'blog', { user_id => $USER_ID }, { order_by => { -desc => 'title' } } ) );

    };
};

subtest 'fetch one' => sub {
    $t->get_ok( '/yancy/api/blog/' . $items{blog}[0]{id} )
      ->status_is( 200 )
      ->json_is( $backend->get( blog => $items{blog}[0]{id} ) );
    $t->get_ok( '/yancy/api/blog/' . $items{blog}[1]{id} )
      ->status_is( 401 )
      ->json_is( { message => 'Unauthorized' } );
};

subtest 'set one' => sub {
    my $new_blog = { %{ $backend->get( blog => $items{blog}[0]{id} ) }, title => 'New Title' };
    delete $new_blog->{id};
    $t->put_ok( '/yancy/api/blog/' . $items{blog}[0]{id} => json => $new_blog )
      ->status_is( 400, 'cannot save blog with user_id' )
      ->json_has( 'errors' )
      ;
    delete $new_blog->{user_id};
    $t->put_ok( '/yancy/api/blog/' . $items{blog}[0]{id} => json => $new_blog )
      ->status_is( 200 )
      ->json_is( { %{ $new_blog }, id => $items{blog}[0]{id}, user_id => $USER_ID } );
    is_deeply $backend->get( blog => $items{blog}[0]{id} ),
        { %{ $new_blog }, id => $items{blog}[0]{id}, user_id => $USER_ID };

    $t->put_ok( '/yancy/api/blog/' . $items{blog}[1]{id} => json => $new_blog )
      ->status_is( 401 )
      ->json_is( { message => 'Unauthorized' } );
};

my $added_id;
subtest 'add one' => sub {
    my $new_blog = {
        title => 'New Post',
        slug => 'new-post',
        markdown => 'New blog post',
        html => 'New blog post',
    };
    $t->post_ok( '/yancy/api/blog' => json => $new_blog )
      ->status_is( 201 );
    $added_id = $t->tx->res->json;
    is_deeply $backend->get( blog => $added_id ),
        { %{ $new_blog }, user_id => $USER_ID, id => $added_id };

    $t->post_ok( '/yancy/api/blog' => json => { %{ $new_blog }, user_id => $USER_ID } )
      ->status_is( 400 )
      ->json_has( 'errors' )
      ;
};

subtest 'delete one' => sub {
    $t->delete_ok( '/yancy/api/blog/' . $added_id )
      ->status_is( 204 )
      ;
    ok !$backend->get( blog => $added_id ), "blog $added_id not exists";

    $t->delete_ok( '/yancy/api/blog/' . $items{blog}[1]{id} )
      ->status_is( 401 )
      ->json_is( { message => 'Unauthorized' } )
      ;
};

done_testing;
