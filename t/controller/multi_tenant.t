
=head1 DESCRIPTION

This test ensures that the "Yancy::MultiTenant" controller works
correctly as an API

=head1 SEE ALSO

L<Yancy::Controller::Yancy::MultiTenant>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Yancy::Controller::Yancy::MultiTenant;

my $schema = \%Local::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
    user => [
        {
            username => 'leela',
            password => '123qwe',
            email => 'leela@example.com',
            access => 'user',
        },
        {
            username => 'fry',
            password => '123qwe',
            email => 'fry@example.com',
            access => 'user',
        },
    ],
);

$items{blog} = [
    {
        title => 'First Post',
        slug => 'first-post',
        markdown => '# First Post',
        html => '<h1>First Post</h1>',
        username => $items{user}[0]{username},
        is_published => 1,
    },
    {
        title => 'Second Post',
        slug => 'second-post',
        markdown => '# Second Post',
        html => '<h1>Second Post</h1>',
        username => $items{user}[0]{username},
        is_published => 1,
    },
    {
        title => 'Other Post',
        slug => 'other-post',
        markdown => '# Other Post',
        html => '<h1>Other Post</h1>',
        username => $items{user}[1]{username},
        is_published => 1,
    },
];
for my $i ( 0..$#{ $items{blog} } ) {
    my $id = $backend->create( blog => $items{blog}[$i] );
    $items{blog}[$i] = $backend->get( blog => $id );
}

local $ENV{MOJO_HOME} = path( $Bin, '..', 'share' );
my $t = Test::Mojo->new( 'Mojolicious' );
my $CONFIG = {
    backend => $backend_url,
    schema => $schema,
};
$t->app->plugin( 'Yancy' => $CONFIG );

my $r = $t->app->routes;
$r->get( '/error/list/noschema' )->to(
    'yancy-multi_tenant#list',
    template => 'blog_list',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/list/nouserid' )->to(
    'yancy-multi_tenant#list',
    template => 'blog_list',
    schema => 'blog',
);
$r->get( '/error/get/noschema' )->to(
    'yancy-multi_tenant#get',
    template => 'blog_view',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/get/noid' )->to(
    'yancy-multi_tenant#get',
    schema => 'blog',
    template => 'blog_view',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/get/nouserid' )->to(
    'yancy-multi_tenant#get',
    template => 'blog_view',
    schema => 'blog',
    id => $items{blog}[0]{id},
);
$r->get( '/error/set/noschema' )->to(
    'yancy-multi_tenant#set',
    template => 'blog_edit',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/set/nouserid' )->to(
    'yancy-multi_tenant#set',
    template => 'blog_edit',
    schema => 'blog',
    id => $items{blog}[0]{id},
);

$r->get( '/error/delete/noschema' )->to(
    'yancy-multi_tenant#delete',
    template => 'blog_delete',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/delete/noid' )->to(
    'yancy-multi_tenant#delete',
    schema => 'blog',
    template => 'blog_delete',
    user_id => $items{user}[0]{username},
);
$r->get( '/error/delete/nouserid' )->to(
    'yancy-multi_tenant#delete',
    template => 'blog_delete',
    schema => 'blog',
    id => $items{blog}[0]{id},
);

my $user = $r->under( '/:user_id' )->to( user_id_field => 'username' );
$user->any( [ 'GET', 'POST' ] => '/edit/:id' )
    ->to( 'yancy-multi_tenant#set',
        schema => 'blog',
        template => 'blog_edit',
    )
    ->name( 'blog.edit' );
$user->any( [ 'GET', 'POST' ] => '/delete/:id' )
    ->to( 'yancy-multi_tenant#delete',
        schema => 'blog',
        template => 'blog_delete',
    )
    ->name( 'blog.delete' );
$user->any( [ 'GET', 'POST' ] => '/delete-forward/:id' )
    ->to( 'yancy-multi_tenant#delete',
        schema => 'blog',
        forward_to => 'blog.list',
    );
$user->any( [ 'GET', 'POST' ] => '/edit' )
    ->to( 'yancy-multi_tenant#set',
        schema => 'blog',
        template => 'blog_edit',
        forward_to => 'blog.view',
    )
    ->name( 'blog.create' );
$user->get( '/:id/:slug' )
    ->to( 'yancy-multi_tenant#get' =>
        schema => 'blog',
        template => 'blog_view',
    )
    ->name( 'blog.view' );
$user->get( '' )
    ->to( 'yancy-multi_tenant#list' =>
        schema => 'blog',
        template => 'blog_list',
    )
    ->name( 'blog.list' );

subtest 'list' => sub {
    $t->get_ok( '/leela' )
      ->text_is( 'article:nth-child(1) h1 a', 'First Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ->text_is( 'article:nth-child(2) h1 a', 'Second Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(2)' )->[0] } )
      ->element_exists( "article:nth-child(1) h1 a[href=/leela/$items{blog}[0]{id}/first-post]" )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ->element_exists( "article:nth-child(2) h1 a[href=/leela/$items{blog}[1]{id}/second-post]" )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(2)' )->[0] } )
      ;

    $t->get_ok( '/leela', { Accept => 'application/json' } )
      ->json_is( { items => [ @{$items{blog}}[0,1] ], total => 2, offset => 0 } )
      ;

    subtest 'errors' => sub {
        $t->get_ok( '/error/list/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/list/nouserid' )
          ->status_is( 500 )
          ->content_like( qr{User ID not defined in stash} );
    };
};

subtest 'get' => sub {
    $t->get_ok( "/leela/$items{blog}[0]{id}/first-post" )
      ->text_is( 'article:nth-child(1) h1', 'First Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ;

    $t->get_ok( "/leela/$items{blog}[0]{id}/first-post", { Accept => 'application/json' } )
      ->json_is( $items{blog}[0] )
      ;

    subtest 'errors' => sub {
        $t->get_ok( '/error/get/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/get/noid' )
          ->status_is( 500 )
          ->content_like( qr{ID field &quot;id&quot; not defined in stash} );
        $t->get_ok( '/error/get/nouserid' )
          ->status_is( 500 )
          ->content_like( qr{User ID not defined in stash} );
        $t->get_ok( "/leela/$items{blog}[2]{id}/other-post" )
          ->status_is( 404, 'post from other user returns not found' );
    };
};

subtest 'set' => sub {

    my $csrf_token;
    subtest 'edit existing' => sub {
        $t->get_ok( "/leela/edit/$items{blog}[0]{id}" )
          ->status_is( 200 )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->attr_is( 'form input[name=title]', value => 'First Post', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->attr_is( 'form input[name=slug]', value => 'first-post', 'slug field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_like( 'form textarea[name=markdown]', qr{\s*\# First Post\s*}, 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_like( 'form textarea[name=html]', qr{\s*<h1>First Post</h1>\s*}, 'html field value correct' )
          ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
          ;

        $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
        my %form_data = (
            title => 'Frist Psot',
            slug => 'frist-psot',
            markdown => '# Frist Psot',
            html => '<h1>Frist Psot</h1>',
            csrf_token => $csrf_token,
            username => $items{user}[1]{username}, # Try to break the user ID
        );
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => form => \%form_data )
          ->status_is( 200 )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->attr_is( 'form input[name=title]', value => 'Frist Psot', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->attr_is( 'form input[name=slug]', value => 'frist-psot', 'slug field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_like( 'form textarea[name=markdown]', qr{\s*\# Frist Psot\s*}, 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_like( 'form textarea[name=html]', qr{\s*<h1>Frist Psot</h1>\s*}, 'html field value correct' )
          ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
          ;

        my $saved_item = $backend->get( blog => $items{blog}[0]{id} );
        is $saved_item->{title}, 'Frist Psot', 'item title saved correctly';
        is $saved_item->{slug}, 'frist-psot', 'item slug saved correctly';
        is $saved_item->{markdown}, '# Frist Psot', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>Frist Psot</h1>', 'item html saved correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username not modified';
    };

    subtest 'create new' => sub {
        $t->get_ok( '/leela/edit' )
          ->status_is( 200 )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->attr_is( 'form input[name=title]', value => '', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->attr_is( 'form input[name=slug]', value => '', 'title field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_is( 'form textarea[name=markdown]', '', 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_is( 'form textarea[name=html]', '', 'html field value correct' )
          ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
          ;

        my %form_data = (
            title => 'Form Post',
            slug => 'form-post',
            markdown => '# Form Post',
            html => '<h1>Form Post</h1>',
            csrf_token => $csrf_token,
            username => $items{user}[1]{username}, # Try to break the user id
        );
        $t->post_ok( '/leela/edit' => form => \%form_data )
          ->status_is( 302 )
          ->header_like( Location => qr{^/leela/\d+/form-post$}, 'forward_to route correct' )
          ;

        my ( $id ) = $t->tx->res->headers->location =~ m{^/leela/(\d+)};
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'Form Post', 'item title created correctly';
        is $saved_item->{slug}, 'form-post', 'item slug created correctly';
        is $saved_item->{markdown}, '# Form Post', 'item markdown created correctly';
        is $saved_item->{html}, '<h1>Form Post</h1>', 'item html created correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username created correctly';
    };

    subtest 'json edit (form params)' => sub {
        my %json_data = (
            title => 'Foirst Post',
            slug => 'foirst-post',
            markdown => '# Foirst Post',
            html => '<h1>Foirst Post</h1>',
            is_published => "false",
        );
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => { Accept => 'application/json' }, form => \%json_data )
          ->status_is( 200 )
          ->json_is( '/id' => $items{blog}[0]{id} )
          ->json_is( '/username' => $items{user}[0]{username} )
          ->json_is( '/title' => 'Foirst Post', 'returned title is correct' )
          ->json_is( '/slug' => 'foirst-post', 'returned slug is correct' )
          ->json_is( '/markdown' => '# Foirst Post', 'returned markdown is correct' )
          ->json_is( '/html' => '<h1>Foirst Post</h1>', 'returned html is correct' )
          ->json_is( '/is_published' => 0, 'is_published set and booleans normalized to 0/1' )
          ;

        my $saved_item = $backend->get( blog => $items{blog}[0]{id} );
        is $saved_item->{title}, 'Foirst Post', 'item title saved correctly';
        is $saved_item->{slug}, 'foirst-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# Foirst Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>Foirst Post</h1>', 'item html saved correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username not modified';
    };

    subtest 'json create (form params)' => sub {
        my %json_data = (
            title => 'JSON Post',
            slug => 'json-post',
            markdown => '# JSON Post',
            html => '<h1>JSON Post</h1>',
        );
        $t->post_ok( '/leela/edit' => { Accept => 'application/json' }, form => \%json_data )
          ->status_is( 201 )
          ->json_has( '/id', 'ID is created' )
          ->json_is( '/title' => 'JSON Post', 'returned title is correct' )
          ->json_is( '/slug' => 'json-post', 'returned slug is correct' )
          ->json_is( '/markdown' => '# JSON Post', 'returned markdown is correct' )
          ->json_is( '/html' => '<h1>JSON Post</h1>', 'returned html is correct' )
          ->json_is( '/username' => $items{user}[0]{username}, 'returned username is correct' )
          ;
        my $id = $t->tx->res->json( '/id' );
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'JSON Post', 'item title saved correctly';
        is $saved_item->{slug}, 'json-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# JSON Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>JSON Post</h1>', 'item html saved correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username saved correctly';
    };

    subtest 'json edit (json body)' => sub {
        my %json_data = (
            title => 'First Post',
            slug => 'first-post',
            markdown => '# First Post',
            html => '<h1>First Post</h1>',
            is_published => "true",
            username => 'zoidberg',
        );
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => { Accept => 'application/json' }, json => \%json_data )
          ->status_is( 200 )
          ->json_is( '/id' => $items{blog}[0]{id} )
          ->json_is( '/username' => $items{user}[0]{username} )
          ->json_is( '/title' => 'First Post', 'returned title is correct' )
          ->json_is( '/slug' => 'first-post', 'returned slug is correct' )
          ->json_is( '/markdown' => '# First Post', 'returned markdown is correct' )
          ->json_is( '/html' => '<h1>First Post</h1>', 'returned html is correct' )
          ->json_is( '/is_published' => 1, 'is_published set and booleans normalized to 0/1' )
          ;

        my $saved_item = $backend->get( blog => $items{blog}[0]{id} );
        is $saved_item->{title}, 'First Post', 'item title saved correctly';
        is $saved_item->{slug}, 'first-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# First Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>First Post</h1>', 'item html saved correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username not modified';
    };

    subtest 'json create' => sub {
        my %json_data = (
            title => 'JSON Body Post',
            slug => 'json-body-post',
            markdown => '# JSON Body Post',
            html => '<h1>JSON Body Post</h1>',
        );
        $t->post_ok( '/leela/edit' => { Accept => 'application/json' }, json => \%json_data )
          ->status_is( 201 )
          ->json_has( '/id', 'ID is created' )
          ->json_is( '/title' => 'JSON Body Post', 'returned title is correct' )
          ->json_is( '/slug' => 'json-body-post', 'returned slug is correct' )
          ->json_is( '/markdown' => '# JSON Body Post', 'returned markdown is correct' )
          ->json_is( '/html' => '<h1>JSON Body Post</h1>', 'returned html is correct' )
          ->json_is( '/username' => $items{user}[0]{username}, 'returned username is correct' )
          ;
        my $id = $t->tx->res->json( '/id' );
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'JSON Body Post', 'item title saved correctly';
        is $saved_item->{slug}, 'json-body-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# JSON Body Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>JSON Body Post</h1>', 'item html saved correctly';
        is $saved_item->{username}, $items{user}[0]{username}, 'item username saved correctly';
    };


    subtest 'errors' => sub {
        $t->get_ok( '/error/set/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/set/nouserid' )
          ->status_is( 500 )
          ->content_like( qr{User ID not defined in stash} );
        $t->get_ok( "/leela/edit/$items{blog}[0]{id}" => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );
        $t->get_ok( '/leela/edit' => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );

        subtest 'failed CSRF validation' => sub {
            $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => form => $items{blog}[0] )
              ->status_is( 400, 'CSRF validation failed gives 400 status' )
              ->text_is( '.errors > li:nth-child(1)', 'CSRF token invalid.' )
              ->element_exists( 'form input[name=title]', 'title field exists' )
              ->attr_is( 'form input[name=title]', value => 'First Post', 'title field value correct' )
              ->element_exists( 'form input[name=slug]', 'slug field exists' )
              ->attr_is( 'form input[name=slug]', value => 'first-post', 'slug field value correct' )
              ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
              ->text_like( 'form textarea[name=markdown]', qr{\s*\# First Post\s*}, 'markdown field value correct' )
              ->element_exists( 'form textarea[name=html]', 'html field exists' )
              ->text_like( 'form textarea[name=html]', qr{\s*<h1>First Post</h1>\s*}, 'html field value correct' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;

            my $new_item = { %{ $items{blog}[0] } };
            delete $new_item->{id};
            $t->post_ok( "/leela/edit" => form => $new_item )
              ->status_is( 400, 'CSRF validation failed gives 400 status' )
              ->text_is( '.errors > li:nth-child(1)', 'CSRF token invalid.' )
              ->element_exists( 'form input[name=title]', 'title field exists' )
              ->attr_is( 'form input[name=title]', value => 'First Post', 'title field value correct' )
              ->element_exists( 'form input[name=slug]', 'slug field exists' )
              ->attr_is( 'form input[name=slug]', value => 'first-post', 'slug field value correct' )
              ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
              ->text_like( 'form textarea[name=markdown]', qr{\s*\# First Post\s*}, 'markdown field value correct' )
              ->element_exists( 'form textarea[name=html]', 'html field exists' )
              ->text_like( 'form textarea[name=html]', qr{\s*<h1>First Post</h1>\s*}, 'html field value correct' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;

        };
    };
};

subtest 'delete' => sub {
    $t->get_ok( "/leela/delete/$items{blog}[0]{id}" )
      ->status_is( 200 )
      ->text_is( p => 'Are you sure?' )
      ->element_exists( 'input[type=submit]', 'submit button exists' )
      ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
      ;

    my $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
    my %token_form = ( form => { csrf_token => $csrf_token } );
    $t->post_ok( "/leela/delete/$items{blog}[0]{id}", %token_form )
      ->status_is( 200 )
      ->text_is( p => 'Item deleted' )
      ;

    ok !$backend->get( blog => $items{blog}[0]{id} ), 'item is deleted';

    $t->post_ok( "/leela/delete-forward/$items{blog}[1]{id}", %token_form )
      ->status_is( 302, 'forward_to sends redirect' )
      ->header_is( Location => '/leela', 'forward_to correctly forwards' )
      ;

    ok !$backend->get( blog => $items{blog}[1]{id} ), 'item is deleted with forwarding';

    my $json_item = $backend->list( blog => { username => $items{user}[0]{username} }, { limit => 1 } )->{items}[0];
    $t->post_ok( '/leela/delete/' . $json_item->{id}, { Accept => 'application/json' } )
      ->status_is( 204 )
      ;
    ok !$backend->get( blog => $json_item->{id} ), 'item is deleted via json';

    subtest 'errors' => sub {
        $t->get_ok( '/error/delete/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/delete/noid' )
          ->status_is( 500 )
          ->content_like( qr{ID field &quot;id&quot; not defined in stash} );
        $t->get_ok( '/error/delete/nouserid' )
          ->status_is( 500 )
          ->content_like( qr{User ID not defined in stash} );
        $t->get_ok( "/leela/$items{blog}[2]{id}/other-post" )
          ->status_is( 404, 'post from other user returns not found' );
        $t->post_ok( "/leela/$items{blog}[2]{id}/other-post" )
          ->status_is( 404, 'post from other user returns not found' );

        my $item = $backend->list( 'blog', { username => $items{user}[0]{username} } )->{items}[0];
        $t->get_ok( "/leela/delete/$item->{id}" => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );

        subtest 'failed CSRF validation' => sub {
            my $item = $backend->list( 'blog', { username => $items{user}[0]{username} } )->{items}[0];
            $t->post_ok( "/leela/delete/$item->{id}" )
              ->status_is( 400 )
              ->content_like( qr{CSRF token invalid\.} )
              ->element_exists( 'input[type=submit]', 'submit button exists' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;
        };

    };
};

done_testing;
