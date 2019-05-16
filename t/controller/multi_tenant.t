
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

my $collections = \%Yancy::Backend::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
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
        user_id => $items{user}[0]{id},
        is_published => 1,
    },
    {
        title => 'Second Post',
        slug => 'second-post',
        markdown => '# Second Post',
        html => '<h1>Second Post</h1>',
        user_id => $items{user}[0]{id},
        is_published => 1,
    },
    {
        title => 'Other Post',
        slug => 'other-post',
        markdown => '# Other Post',
        html => '<h1>Other Post</h1>',
        user_id => $items{user}[1]{id},
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
    collections => $collections,
};
$t->app->plugin( 'Yancy' => $CONFIG );

my $r = $t->app->routes;
$r->get( '/error/list/nocollection' )->to(
    'yancy-multi_tenant#list',
    template => 'blog_list',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/list/nouserid' )->to(
    'yancy-multi_tenant#list',
    template => 'blog_list',
    collection => 'blog',
);
$r->get( '/error/get/nocollection' )->to(
    'yancy-multi_tenant#get',
    template => 'blog_view',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/get/noid' )->to(
    'yancy-multi_tenant#get',
    collection => 'blog',
    template => 'blog_view',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/get/nouserid' )->to(
    'yancy-multi_tenant#get',
    template => 'blog_view',
    collection => 'blog',
    id => $items{blog}[0]{id},
);
$r->get( '/error/set/nocollection' )->to(
    'yancy-multi_tenant#set',
    template => 'blog_edit',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/set/nouserid' )->to(
    'yancy-multi_tenant#set',
    template => 'blog_edit',
    collection => 'blog',
    id => $items{blog}[0]{id},
);

$r->get( '/error/delete/nocollection' )->to(
    'yancy-multi_tenant#delete',
    template => 'blog_delete',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/delete/noid' )->to(
    'yancy-multi_tenant#delete',
    collection => 'blog',
    template => 'blog_delete',
    user_id => $items{user}[0]{id},
);
$r->get( '/error/delete/nouserid' )->to(
    'yancy-multi_tenant#delete',
    template => 'blog_delete',
    collection => 'blog',
    id => $items{blog}[0]{id},
);

my $user = $r->under( '/:username', sub {
    my ( $c ) = @_;
    my $username = $c->stash( 'username' );
    my @users = $c->yancy->list( user => { username => $username } );
    if ( my $user = $users[0] ) {
        $c->stash( user_id => $user->{id} );
        return 1;
    }
    return $c->reply->not_found;
} );

$user->any( [ 'GET', 'POST' ] => '/edit/:id' )
    ->to( 'yancy-multi_tenant#set',
        collection => 'blog',
        template => 'blog_edit',
    )
    ->name( 'blog.edit' );
$user->any( [ 'GET', 'POST' ] => '/delete/:id' )
    ->to( 'yancy-multi_tenant#delete',
        collection => 'blog',
        template => 'blog_delete',
    )
    ->name( 'blog.delete' );
$user->any( [ 'GET', 'POST' ] => '/delete-forward/:id' )
    ->to( 'yancy-multi_tenant#delete',
        collection => 'blog',
        forward_to => 'blog.list',
    );
$user->any( [ 'GET', 'POST' ] => '/edit' )
    ->to( 'yancy-multi_tenant#set',
        collection => 'blog',
        template => 'blog_edit',
        forward_to => 'blog.view',
    )
    ->name( 'blog.create' );
$user->get( '/:id/:slug' )
    ->to( 'yancy-multi_tenant#get' =>
        collection => 'blog',
        template => 'blog_view',
    )
    ->name( 'blog.view' );
$user->get( '' )
    ->to( 'yancy-multi_tenant#list' =>
        collection => 'blog',
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
        $t->get_ok( '/error/list/nocollection' )
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
        $t->get_ok( '/error/get/nocollection' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/get/noid' )
          ->status_is( 500 )
          ->content_like( qr{ID not defined in stash} );
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
          ->element_exists( 'form input[name=title][value="First Post"]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=first-post]', 'slug field value correct' )
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
            user_id => $items{user}[1]{id}, # Try to break the user ID
        );
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => form => \%form_data )
          ->status_is( 200 )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->element_exists( 'form input[name=title][value="Frist Psot"]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=frist-psot]', 'slug field value correct' )
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
        is $saved_item->{user_id}, $items{user}[0]{id}, 'item user_id not modified';
    };

    subtest 'create new' => sub {
        $t->get_ok( '/leela/edit' )
          ->status_is( 200 )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->element_exists( 'form input[name=title][value=]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=]', 'slug field value correct' )
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
            user_id => $items{user}[1]{id}, # Try to break the user id
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
        is $saved_item->{user_id}, $items{user}[0]{id}, 'item user_id created correctly';
    };

    subtest 'json edit' => sub {
        my %json_data = (
            title => 'First Post',
            slug => 'first-post',
            markdown => '# First Post',
            html => '<h1>First Post</h1>',
            is_published => "true",
        );
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => { Accept => 'application/json' }, form => \%json_data )
          ->status_is( 200 )
          ->json_is( {
            id => $items{blog}[0]{id},
            user_id => $items{user}[0]{id},
            %json_data,
            is_published => 1, # booleans normalized to 0/1
          } );

        my $saved_item = $backend->get( blog => $items{blog}[0]{id} );
        is $saved_item->{title}, 'First Post', 'item title saved correctly';
        is $saved_item->{slug}, 'first-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# First Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>First Post</h1>', 'item html saved correctly';
        is $saved_item->{user_id}, $items{user}[0]{id}, 'item user_id not modified';
    };

    subtest 'json create' => sub {
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
          ->json_is( '/user_id' => $items{user}[0]{id}, 'returned user_id is correct' )
          ;
        my $id = $t->tx->res->json( '/id' );
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'JSON Post', 'item title saved correctly';
        is $saved_item->{slug}, 'json-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# JSON Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>JSON Post</h1>', 'item html saved correctly';
        is $saved_item->{user_id}, $items{user}[0]{id}, 'item user_id saved correctly';
    };

    subtest 'errors' => sub {
        $t->get_ok( '/error/set/nocollection' )
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

        my $form_no_fields = {
            csrf_token => $csrf_token,
        };
        $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => form => $form_no_fields )
          ->status_is( 400, 'invalid form input gives 400 status' )
          ->text_is( '.errors > li:nth-child(1)', 'Missing property. (/markdown)' )
          ->text_is( '.errors > li:nth-child(2)', 'Missing property. (/title)' )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->element_exists( 'form input[name=title][value=]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=]', 'slug field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_is( 'form textarea[name=markdown]', '', 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_is( 'form textarea[name=html]', '', 'html field value correct' )
          ;

        $t->post_ok( '/leela/edit' => form => $form_no_fields )
          ->status_is( 400, 'invalid form input gives 400 status' )
          ->text_is( '.errors > li:nth-child(1)', 'Missing property. (/markdown)' )
          ->text_is( '.errors > li:nth-child(2)', 'Missing property. (/title)' )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->element_exists( 'form input[name=title][value=]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=]', 'slug field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_is( 'form textarea[name=markdown]', '', 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_is( 'form textarea[name=html]', '', 'html field value correct' )
          ;

        subtest 'failed CSRF validation' => sub {
            $t->post_ok( "/leela/edit/$items{blog}[0]{id}" => form => $items{blog}[0] )
              ->status_is( 400, 'CSRF validation failed gives 400 status' )
              ->text_is( '.errors > li:nth-child(1)', 'CSRF token invalid.' )
              ->element_exists( 'form input[name=title]', 'title field exists' )
              ->element_exists( 'form input[name=title][value="First Post"]', 'title field value correct' )
              ->element_exists( 'form input[name=slug]', 'slug field exists' )
              ->element_exists( 'form input[name=slug][value=first-post]', 'slug field value correct' )
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
              ->element_exists( 'form input[name=title][value="First Post"]', 'title field value correct' )
              ->element_exists( 'form input[name=slug]', 'slug field exists' )
              ->element_exists( 'form input[name=slug][value=first-post]', 'slug field value correct' )
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

    my $json_item = $backend->list( blog => { user_id => $items{user}[0]{id} }, { limit => 1 } )->{items}[0];
    $t->post_ok( '/leela/delete/' . $json_item->{id}, { Accept => 'application/json' } )
      ->status_is( 204 )
      ;
    ok !$backend->get( blog => $json_item->{id} ), 'item is deleted via json';

    subtest 'errors' => sub {
        $t->get_ok( '/error/delete/nocollection' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/delete/noid' )
          ->status_is( 500 )
          ->content_like( qr{ID not defined in stash} );
        $t->get_ok( '/error/delete/nouserid' )
          ->status_is( 500 )
          ->content_like( qr{User ID not defined in stash} );
        $t->get_ok( "/leela/$items{blog}[2]{id}/other-post" )
          ->status_is( 404, 'post from other user returns not found' );
        $t->post_ok( "/leela/$items{blog}[2]{id}/other-post" )
          ->status_is( 404, 'post from other user returns not found' );

        my $item = $backend->list( 'blog', { user_id => $items{user}[0]{id} } )->{items}[0];
        $t->get_ok( "/leela/delete/$item->{id}" => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );

        subtest 'failed CSRF validation' => sub {
            my $item = $backend->list( 'blog', { user_id => $items{user}[0]{id} } )->{items}[0];
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
