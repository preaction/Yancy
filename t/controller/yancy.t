
=head1 DESCRIPTION

This test ensures that the main "Yancy" controller works correctly as an
API

=head1 SEE ALSO

L<Yancy::Controller::Yancy>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Scalar::Util qw( blessed );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Yancy::Controller::Yancy;

my $schema = \%Yancy::Backend::Test::SCHEMA;

my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
            access => 'user',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => 'ignore',
            access => 'user',
        },
    ],
);
my $backend_class = blessed $backend;

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
push @{ $r->namespaces}, 'Local::Controller';
$r->get( '/error/list/noschema' )->to( 'yancy#list', template => 'blog_list' );
$r->get( '/error/get/noschema' )->to( 'yancy#get', template => 'blog_view' );
$r->get( '/error/get/noid' )->to( 'yancy#get', schema => 'blog', template => 'blog_view' );
$r->get( '/error/get/id404' )->to( 'yancy#get', schema => 'blog', template => 'blog_view', id => 70000 ); # this is a hardcoded ID, picked to be much higher than will realistically occur even with many tests
$r->get( '/error/set/noschema' )->to( 'yancy#set', template => 'blog_edit' );
$r->get( '/error/delete/noschema' )->to( 'yancy#delete', template => 'blog_delete' );
$r->get( '/error/delete/noid' )->to( 'yancy#delete', schema => 'blog', template => 'blog_delete' );

$r->get( '/extend/error/get/id404' )->to(
    'extend-yancy#get',
    schema => 'blog',
    template => 'extend/blog_view',
    id => 70000, # this is a hardcoded ID, picked to be much higher than will realistically occur even with many tests
);
$r->get( '/extend/:id/:slug' )
    ->to(
        'extend-yancy#get',
        schema => 'blog',
        template => 'extend/blog_view',
    )
    ->name( 'extend.blog.view' );
$r->get( '/extend/:page', { page => 1 } )
    ->to(
        'extend-yancy#list',
        schema => 'blog',
        template => 'extend/blog_list',
    )
    ->name( 'extend.blog.list' );

$r->get( '/default/list_template/schema-properties' )
    ->to( 'yancy#list' => schema => 'blog' );
$r->get( '/default/list_template/schema-x-list-columns' )
    ->to( 'yancy#list' => schema => 'user', table => { show_filter => 1 } );
$r->get( '/default/list_template/stash-properties' )
    ->to( 'yancy#list' =>
        schema => 'blog',
        properties => [
            { title => 'Title', template => '<a href="/{id}/{slug}">{title}</a>' },
        ],
        table => {
            thead => 0, # Disable thead
            class => 'table-responsive',
            id => 'mytable',
        },
    );

$r->any( [ 'GET', 'POST' ] => '/user/:id/edit' )
    ->to( 'yancy#set', schema => 'user', template => 'user_edit' )
    ->name( 'user.edit' );
$r->any( [ 'GET', 'POST' ] => '/user/:id/profile' )
    ->to( 'yancy#set',
        schema => 'user',
        template => 'user_profile_edit',
        properties => [qw( email age )], # Only allow email/age
    )
    ->name( 'profile.edit' );

$r->any( [ 'GET', 'POST' ] => '/blog/edit/:id' )
    ->to( 'yancy#set', schema => 'blog', template => 'blog_edit' )
    ->name( 'blog.edit' );
$r->any( [ 'GET', 'POST' ] => '/blog/delete/:id' )
    ->to( 'yancy#delete', schema => 'blog', template => 'blog_delete' )
    ->name( 'blog.delete' );
$r->any( [ 'GET', 'POST' ] => '/blog/delete-forward/:id' )
    ->to( 'yancy#delete', schema => 'blog', forward_to => 'blog.list' );
$r->any( [ 'GET', 'POST' ] => '/blog/edit' )
    ->to( 'yancy#set', schema => 'blog', template => 'blog_edit', forward_to => 'blog.view' )
    ->name( 'blog.create' );
$r->get( '/blog/view/:id/:slug' )
    ->to( 'yancy#get' => schema => 'blog', template => 'blog_view' )
    ->name( 'blog.view' );
$r->get( '/blog/page/<page:num>', { page => 1 } )
    ->to( 'yancy#list' => schema => 'blog', template => 'blog_list', order_by => { -desc => 'title' } )
    ->name( 'blog.list' );
$r->get( '/blog/user/1/:page', { filter => { id => $items{blog}[0]{id} }, page => 1 } )
    ->to( 'yancy#list' => schema => 'blog', template => 'blog_list' );
$r->get( '/blog/usersub/:userid/:page', {
        filter => sub {
            my ( $c ) = @_;
            return {
                id => $c->stash( 'userid' ),
            };
        },
        page => 1,
    } )
    ->to( 'yancy#list' => schema => 'blog', template => 'blog_list' );

subtest 'list' => sub {
    $t->get_ok( '/blog/page' )
      ->text_is( 'article:nth-child(1) h1 a', 'Second Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ->text_is( 'article:nth-child(2) h1 a', 'First Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(2)' )->[0] } )
      ->element_exists( "article:nth-child(1) h1 a[href=/blog/view/$items{blog}[1]{id}/second-post]" )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ->element_exists( "article:nth-child(2) h1 a[href=/blog/view/$items{blog}[0]{id}/first-post]" )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(2)' )->[0] } )
      ->element_exists( ".pager a[href=/blog/page]", 'pager link exists' )
      ->or( sub { diag shift->tx->res->dom->at( '.pager' ) } )
      ;

    subtest '$limit and pagination' => sub {
        $t->get_ok( '/blog/page?$limit=1' )
          ->text_is( 'article:nth-child(1) h1 a', 'Second Post' )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
          ->element_exists( "article:nth-child(1) h1 a[href=/blog/view/$items{blog}[1]{id}/second-post]" )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
          ->element_exists( ".pager a[href=/blog/page/2]", 'next page link exists' )
          ->or( sub { diag shift->tx->res->dom->at( '.pager' ) } )
          ->element_exists_not( ".pager a[href=/blog/page/3]", 'there is no third page' )
          ->or( sub { diag shift->tx->res->dom->at( '.pager' ) } )
          ;
    };

    $t->get_ok( '/blog/page', { Accept => 'application/json' } )
      ->json_is( { items => [ @{$items{blog}}[1,0] ], total => 2, offset => 0 } )
      ;

    subtest 'list with filter hashref' => sub {
        $t->get_ok( '/blog/user/1' )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'First Post' )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
          ->element_exists( "article:nth-child(1) h1 a[href=/blog/view/$items{blog}[0]{id}/first-post]" )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
          ->element_exists_not( "article:nth-child(2) h1 a[href=/blog/view/$items{blog}[1]{id}/second-post]" )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(2)' )->[0] } )
          ->element_exists( ".pager a[href=/blog/user/1]", 'pager link exists' )
          ->or( sub { diag shift->tx->res->dom->at( '.pager' ) } )
          ;
    };

    subtest 'list with filter subref' => sub {
        $t->get_ok( '/blog/usersub/' . $items{blog}[0]{id} )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'First Post' )
          ->or( sub { diag shift->tx->res->body } )
          ->element_exists( "article:nth-child(1) h1 a[href=/blog/view/$items{blog}[0]{id}/first-post]" )
          ->or( sub { diag shift->tx->res->body } )
          ->element_exists_not( "article:nth-child(2) h1 a[href=/blog/view/$items{blog}[1]{id}/second-post]" )
          ->or( sub { diag shift->tx->res->body } )
          ->element_exists( ".pager a[href=/blog/usersub/$items{blog}[0]{id}]", 'pager link exists' )
          ->or( sub { diag shift->tx->res->dom->at( '.pager' ) } )
          ;
        $t->get_ok( '/blog/usersub/' . $items{blog}[1]{id} )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'Second Post' )
          ->or( sub { diag shift->tx->res->body } )
          ->element_exists( "article:nth-child(1) h1 a[href=/blog/view/$items{blog}[1]{id}/second-post]" )
          ->or( sub { diag shift->tx->res->body } )
          ->element_exists( ".pager a[href=/blog/usersub/$items{blog}[1]{id}]", 'pager link exists' )
          ->or( sub { diag shift->tx->res->body } )
          ;
    };

    subtest 'list with query filter' => sub {
        $t->get_ok( '/blog/page', form => { slug => 'first' } )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'First Post', 'first post is found' )
          ->get_ok( '/blog/page', form => { slug => 'second' } )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'Second Post', 'second post is found' )
          ->get_ok( '/blog/page', form => { slug => [qw( first second )] } )
          ->status_is( 200 )
          ->text_is( 'article:nth-child(1) h1 a', 'Second Post', 'only last value is used with multiple values' )
          ->element_exists_not( 'article:nth-child(2) h1 a', 'only last value is used with multiple values' )
          ->get_ok( '/blog/page', form => { slug => 'first', title => 'Second' } )
          ->status_is( 200 )
          ->element_exists_not( 'article', 'no results found (default to "$match: all")' )
          ;
    };

    subtest 'list with non-html format' => sub {
        $t->get_ok( '/blog/page/1.rss', { Accept => 'application/rss+xml' } )->status_is( 200 )
          ->text_is( 'item:nth-of-type(1) title', 'Second Post' )
          ->or( sub { diag shift->tx->res->dom( 'item:nth-of-type(1)' )->[0] } )
          ->text_is( 'item:nth-of-type(2) title', 'First Post' )
          ->or( sub { diag shift->tx->res->dom( 'item:nth-of-type(2)' )->[0] } )
          ;
    };

    subtest 'errors' => sub {
        $t->get_ok( '/error/list/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
    };

    subtest 'subclassing/extending' => sub {
        $t->get_ok( '/extend' )->status_is( 200 )
          ->text_is( '#extended', 1, 'extended stash item exists' )
          ->element_exists( 'article:nth-child(1)', 'item list has 1 element' )
          ->element_exists_not( 'article:nth-child(2)', 'item list reduced to 1 element' )
          ;
    };
};

subtest 'get' => sub {
    $t->get_ok( "/blog/view/$items{blog}[0]{id}/first-post" )
      ->text_is( 'article:nth-child(1) h1', 'First Post' )
      ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
      ;

    $t->get_ok( "/blog/view/$items{blog}[0]{id}/first-post", { Accept => 'application/json' } )
      ->json_is( $items{blog}[0] )
      ;

    subtest 'errors' => sub {
        $t->get_ok( '/error/get/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( '/error/get/noid' )
          ->status_is( 500 )
          ->content_like( qr{ID field &quot;id&quot; not defined in stash} );
        $t->get_ok( '/error/get/id404' )
          ->status_is( 404 )
          ->content_like( qr{Page not found} );
    };

    subtest 'subclassing/extending' => sub {
        $t->get_ok( "/extend/$items{blog}[0]{id}/first-post" )
          ->text_is( 'article:nth-child(1) h1', 'Extended' )
          ->or( sub { diag shift->tx->res->dom( 'article:nth-child(1)' )->[0] } )
          ->text_is( '#extended', 1, 'extended stash item exists' )
          ;

        subtest 'errors' => sub {
            $t->get_ok( '/extend/error/get/id404' )
              ->status_is( 404 )
              ->content_like( qr{Page not found} );
        };
    };
};

subtest 'default list template (yancy/table.html.ep)' => sub {
    $t->get_ok( '/default/list_template/schema-properties' )->status_is( 200 )
        ->element_exists( 'table', 'table exists' )
        ->element_exists( 'thead', 'thead exists' )
        ->element_count_is( 'tbody tr', scalar @{ $items{blog} }, 'tbody row count is correct' )
        ->text_like( 'tbody tr td:first-child', qr{\s*$items{blog}[0]{id}\s*},
            'first column (by x-order) is correct'
        )
        ;
    $t->get_ok( '/default/list_template/schema-x-list-columns' )->status_is( 200 )
        ->element_exists( 'table', 'table exists' )
        ->element_exists( 'thead', 'thead exists' )
        ->element_exists( 'form', 'filter form exists' )
        ->element_exists( '[name=username]', 'username filter field exists' )
        ->element_count_is( 'tbody tr', scalar @{ $items{user} }, 'tbody row count is correct' )
        ->text_like( 'tbody tr td:first-child', qr{\s*$items{user}[0]{username}\s*},
            'first column (by x-list-columns) is correct'
        )
        ;
    $t->get_ok( '/default/list_template/schema-x-list-columns?username=joel' )->status_is( 200 )
        ->element_count_is( 'tbody tr', 1, 'tbody row count is correct' )
        ->text_like( 'tbody tr td:first-child', qr{\s*$items{user}[1]{username}\s*},
            'first column (by x-list-columns) is correct'
        )
        ;
    $t->get_ok( '/default/list_template/stash-properties' )->status_is( 200 )
        ->element_exists( '#mytable', 'id exists' )
        ->element_exists_not( 'thead', 'thead does not exist' )
        ->element_exists( '.table-responsive', 'class exists' )
        ->element_count_is( 'tbody tr', scalar @{ $items{blog} }, 'tbody row count is correct' )
        ->element_exists( 'tbody tr td:first-child a[href=/' . $items{blog}[0]{id} . '/' . $items{blog}[0]{slug} . ']',
            'template html is added in correctly',
        )
        ->text_is( 'tbody tr td:first-child a', $items{blog}[0]{title}, 'template is filled in correctly' )
        ->or( sub { diag shift->tx->res->dom->at( 'table' ) } )
        ;
};

subtest 'set' => sub {

    my $csrf_token;
    subtest 'edit existing' => sub {
        $t->get_ok( "/blog/edit/$items{blog}[0]{id}" )
          ->status_is( 200 )
          ->text_is( 'h1', 'Editing first-post', 'item stash is set' )
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
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( "/blog/edit/$items{blog}[0]{id}" => form => \%form_data );
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 200 )
          ->text_is( 'h1', 'Editing frist-psot', 'item stash is set' )
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
        is $saved_item->{username}, $items{user}[0]{username}, 'item username not modified';
    };

    subtest 'create new' => sub {
        $t->get_ok( '/blog/edit' )
          ->status_is( 200 )
          ->element_exists_not( 'h1', 'item stash is not set' )
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
            is_published => 1,
            csrf_token => $csrf_token,
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( '/blog/edit' => form => \%form_data );
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 302 )
          ->header_like( Location => qr{^/blog/view/\d+/form-post$}, 'forward_to route correct' )
          ;

        my ( $id ) = $t->tx->res->headers->location =~ m{^/blog/view/(\d+)/};
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'Form Post', 'item title created correctly';
        is $saved_item->{slug}, 'form-post', 'item slug created correctly';
        is $saved_item->{markdown}, '# Form Post', 'item markdown created correctly';
        is $saved_item->{html}, '<h1>Form Post</h1>', 'item html created correctly';
    };

    subtest 'json edit' => sub {
        my %json_data = (
            title => 'First Post',
            slug => 'first-post',
            markdown => '# First Post',
            html => '<h1>First Post</h1>',
            is_published => "true",
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( "/blog/edit/$items{blog}[0]{id}" => { Accept => 'application/json' }, form => \%json_data );
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 200 )
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
            title => 'JSON Post',
            slug => 'json-post',
            markdown => '# JSON Post',
            html => '<h1>JSON Post</h1>',
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( '/blog/edit' => { Accept => 'application/json' }, form => \%json_data );
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 201 )
          ->json_has( '/id', 'ID is created' )
          ->json_is( '/title' => 'JSON Post', 'returned title is correct' )
          ->json_is( '/slug' => 'json-post', 'returned slug is correct' )
          ->json_is( '/markdown' => '# JSON Post', 'returned markdown is correct' )
          ->json_is( '/html' => '<h1>JSON Post</h1>', 'returned html is correct' )
          ;
        my $id = $t->tx->res->json( '/id' );
        my $saved_item = $backend->get( blog => $id );
        is $saved_item->{title}, 'JSON Post', 'item title saved correctly';
        is $saved_item->{slug}, 'json-post', 'item slug saved correctly';
        is $saved_item->{markdown}, '# JSON Post', 'item markdown saved correctly';
        is $saved_item->{html}, '<h1>JSON Post</h1>', 'item html saved correctly';
    };

    subtest 'save data with numeric fields' => sub {
        $t->get_ok( "/user/$items{user}[0]{username}/edit" )
          ->status_is( 200 )
          ->text_is( 'h1', 'Editing doug', 'item stash is set' )
          ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
          ;

        $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
        my %form_data = (
            username => 'preaction',
            email => 'preaction@example.com',
            password => 'ignore',
            access => 'user',
            age => 37,
            csrf_token => $csrf_token,
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( "/user/$items{user}[0]{username}/edit" => form => \%form_data );
            $items{user}[0]{username} = $form_data{username}; # x-id-field
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 200 )
          ->or( sub { diag shift->tx->res->body } )
          ;

        my $saved_item = $backend->get( user => $items{user}[0]{username} );
        is $saved_item->{username}, 'preaction', 'item username saved correctly';
        is $saved_item->{email}, 'preaction@example.com', 'item email saved correctly';
        is $saved_item->{password}, 'ignore', 'item password saved correctly';
        is $saved_item->{access}, 'user', 'item access saved correctly';
        is $saved_item->{age}, 37, 'item age saved correctly';
    };

    subtest 'save partial data' => sub {
        $t->get_ok( "/user/$items{user}[0]{username}/profile" )
          ->status_is( 200 )
          ->text_is( 'h1', 'Editing preaction', 'item stash is set' )
          ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
          ;

        $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
        my %form_data = (
            email => 'preaction@example.net',
            age => 28,
            csrf_token => $csrf_token,
            password => '', # exercise stripping password=emptystring
        );

        {
            my @warnings;
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            $t->post_ok( "/user/$items{user}[0]{username}/profile" => form => \%form_data );
            ok !@warnings,
                'no warnings generated by post' or diag explain \@warnings;
        }

        $t->status_is( 200 )
          ->or( sub { diag shift->tx->res->body } )
          ;

        my $saved_item = $backend->get( user => $items{user}[0]{username} );
        is $saved_item->{username}, 'preaction', 'item username not modified';
        is $saved_item->{email}, 'preaction@example.net', 'item email saved correctly';
        is $saved_item->{password}, 'ignore', 'item password not modified';
        is $saved_item->{access}, 'user', 'item access not modified';
        is $saved_item->{age}, 28, 'item age not modified';

        subtest '(error) pass in extra data' => sub {
            $t->get_ok( "/user/$items{user}[0]{username}/profile" )
              ->status_is( 200 )
              ->text_is( 'h1', 'Editing preaction', 'item stash is set' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;

            $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
            my %form_data = (
                email => 'preaction@example.org',
                age => 80,
                access => 'admin',
                csrf_token => $csrf_token,
            );

            {
                my @warnings;
                local $SIG{__WARN__} = sub { push @warnings, @_ };
                ok !@warnings,
                    'no warnings generated by post' or diag explain \@warnings;
            }

            $t->post_ok( "/user/$items{user}[0]{username}/profile" => form => \%form_data )
              ->status_is( 400 )
              ->text_is( '.errors > li:nth-child(1)', 'Properties not allowed: access. (/)' )
              ->or( sub { diag shift->tx->res->body } )
              ;

            my $saved_item = $backend->get( user => $items{user}[0]{username} );
            is $saved_item->{email}, 'preaction@example.net', 'item email not modified';
            is $saved_item->{access}, 'user', 'item access not modified';
            is $saved_item->{age}, 28, 'item age not modified';
        };

    };

    subtest 'errors' => sub {
        $t->get_ok( '/error/set/noschema' )
          ->status_is( 500 )
          ->content_like( qr{Schema name not defined in stash} );
        $t->get_ok( "/blog/edit/$items{blog}[0]{id}" => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );
        $t->get_ok( '/blog/edit' => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );

        my $form_no_fields = {
            csrf_token => $csrf_token,
        };
        $t->post_ok( "/blog/edit/$items{blog}[0]{id}" => form => $form_no_fields )
          ->status_is( 400, 'invalid form input gives 400 status' )
          ->text_is( '.errors > li:nth-child(1)', 'Missing property. (/markdown)' )
          ->text_is( '.errors > li:nth-child(2)', 'Missing property. (/title)' )
          ->text_is( 'h1', 'Editing first-post', 'item stash is set' )
          ->element_exists( 'form input[name=title]', 'title field exists' )
          ->element_exists( 'form input[name=title][value=]', 'title field value correct' )
          ->element_exists( 'form input[name=slug]', 'slug field exists' )
          ->element_exists( 'form input[name=slug][value=]', 'slug field value correct' )
          ->element_exists( 'form textarea[name=markdown]', 'markdown field exists' )
          ->text_is( 'form textarea[name=markdown]', '', 'markdown field value correct' )
          ->element_exists( 'form textarea[name=html]', 'html field exists' )
          ->text_is( 'form textarea[name=html]', '', 'html field value correct' )
          ;

        $t->post_ok( '/blog/edit' => form => $form_no_fields )
          ->status_is( 400, 'invalid form input gives 400 status' )
          ->text_is( '.errors > li:nth-child(1)', 'Missing property. (/markdown)' )
          ->text_is( '.errors > li:nth-child(2)', 'Missing property. (/title)' )
          ->element_exists_not( 'h1', 'item stash is not set' )
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
            $t->post_ok( "/blog/edit/$items{blog}[0]{id}" => form => $items{blog}[0] )
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
            $t->post_ok( "/blog/edit" => form => $new_item )
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

        subtest 'try to save readonly field' => sub {
            $t->get_ok( "/user/$items{user}[0]{username}/edit" )
              ->status_is( 200 )
              ->text_is( 'h1', 'Editing preaction', 'item stash is set' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;

            $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
            my %form_data = (
                id => 721,
                email => 'doug@example.org',
                username => 'ERROR',
                name => 'ERROR NAME',
                password => 'ERROR PASSWORD',
                csrf_token => $csrf_token,
            );

            $t->post_ok( "/user/$items{user}[0]{username}/edit" => form => \%form_data )
              ->status_is( 400, 'invalid form input gives 400 status' )
              ->or( sub { diag shift->tx->res->body } )
              ->text_is( '.errors > li:nth-child(1)', 'Read-only. (/id)' )
              ;

            ok !$backend->get( user => $form_data{id} ), 'id not modified';
        };

        subtest 'backend method dies (set)' => sub {
            no strict 'refs';
            no warnings 'redefine';
            local *{$backend_class . '::set'} = sub { die "Died" };

            my %form_data = (
                email => 'doug@example.org',
                username => 'preaction',
                name => 'Doug Bell',
                password => '123qwe',
                csrf_token => $csrf_token,
            );

            $t->post_ok( "/user/$items{user}[0]{username}/edit" => form => \%form_data )
              ->status_is( 500, 'backend dies gives 500 error' )
              ->or( sub { diag shift->tx->res->body } )
              ->text_like( '.errors > li:nth-child(1)', qr{Died at } )
              ;
        };

        subtest 'backend method dies (create)' => sub {
            no strict 'refs';
            no warnings 'redefine';
            local *{$backend_class . '::create'} = sub { die "Died" };

            my %form_data = (
                title => 'Form Post',
                slug => 'form-post',
                markdown => '# Form Post',
                html => '<h1>Form Post</h1>',
                csrf_token => $csrf_token,
            );

            $t->post_ok( "/blog/edit" => form => \%form_data )
              ->status_is( 500, 'backend dies gives 500 error' )
              ->or( sub { diag shift->tx->res->body } )
              ->text_like( '.errors > li:nth-child(1)', qr{Died at } )
              ;
        };
    };
};

subtest 'delete' => sub {
    $t->get_ok( "/blog/delete/$items{blog}[0]{id}" )
      ->status_is( 200 )
      ->text_is( p => 'Are you sure?' )
      ->element_exists( 'input[type=submit]', 'submit button exists' )
      ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
      ;

    my $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
    my %token_form = ( form => { csrf_token => $csrf_token } );
    $t->post_ok( "/blog/delete/$items{blog}[0]{id}", %token_form )
      ->status_is( 200 )
      ->text_is( p => 'Item deleted' )
      ;

    ok !$backend->get( blog => $items{blog}[0]{id} ), 'item is deleted';

    $t->post_ok( "/blog/delete-forward/$items{blog}[1]{id}", %token_form )
      ->status_is( 302, 'forward_to sends redirect' )
      ->header_is( Location => '/blog/page', 'forward_to correctly forwards' )
      ;

    ok !$backend->get( blog => $items{blog}[1]{id} ), 'item is deleted with forwarding';

    my $json_item = $backend->list( blog => {}, { limit => 1 } )->{items}[0];
    $t->post_ok( '/blog/delete/' . $json_item->{id}, { Accept => 'application/json' } )
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
        $t->get_ok( "/blog/delete/$items{blog}[0]{id}" => { Accept => 'application/json' } )
          ->status_is( 400 )
          ->json_is( {
            errors => [
                { message => 'GET request for JSON invalid' },
            ],
        } );

        subtest 'failed CSRF validation' => sub {
            my $item = $backend->list( 'blog' )->{items}[0];
            $t->post_ok( "/blog/delete/$item->{id}" )
              ->status_is( 400 )
              ->content_like( qr{CSRF token invalid\.} )
              ->element_exists( 'input[type=submit]', 'submit button exists' )
              ->element_exists( 'form input[name=csrf_token]', 'CSRF token field exists' )
              ;
        };

    };
};

done_testing;
