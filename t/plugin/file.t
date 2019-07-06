
=head1 DESCRIPTION

This tests the capabilities of the L<Yancy::Plugin::File> plugin.

=head1 SEE ALSO

L<Yancy>

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path tempdir );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;
use Mojo::Upload;

my $root = tempdir;

my ( $backend_url, $backend, %items ) = init_backend(
    \%Yancy::Backend::Test::SCHEMA,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
            plugin => 'password',
            access => 'admin',
        },
    ],
);

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->log->level( 'debug' );
$t->app->log->handle( \*STDERR );
push @{ $t->app->renderer->paths }, path( $Bin, '..', 'share', 'templates' );
push @{ $t->app->static->paths }, $root;
$t->app->plugin( 'Yancy' => {
    backend => $backend_url,
    schema => \%Yancy::Backend::Test::SCHEMA,
} );
$t->app->yancy->plugin( File => {
    file_root => $root->child( 'uploads' ),
    url_root => '/uploads',
    temp_ttl => 0,
} );
$t->app->routes->get( '/user/:username' )->to(
    'yancy#get',
    schema => 'user',
    template => 'user',
    id_field => 'username',
)->name( 'user.get' );
$t->app->routes->any( [qw( GET POST )], '/user/:username/edit' )->to(
    'yancy#set',
    schema => 'user',
    forward_to => 'user.get',
    template => 'user_edit',
    id_field => 'username',
);

my $spec_asset = Mojo::Asset::File->new( path => path( $Bin, '..', 'share', 'file.txt' ) );
my $spec_digest = 'a5105d3fcba551031e7abdb25f9bbdb2ad3a9ffa';
my @spec_digest_path = grep $_, split /(..)/, $spec_digest, 3;
my $spec_file_path = $root->child( 'uploads', @spec_digest_path, 'file.txt' );
my $spec_url_path = join '/', '', 'uploads', @spec_digest_path, 'file.txt';

my $avatar_asset = Mojo::Asset::File->new( path => path( $Bin, '..', 'share', 'avatar.jpg' ) );
my $avatar_digest = 'aae1681dce597a336fd7d4c847b00128d5ac969f';
my @avatar_digest_path = grep $_, split /(..)/, $avatar_digest, 3;
my $avatar_file_path = $root->child( 'uploads', @avatar_digest_path, 'avatar.jpg' );
my $avatar_url_path = join '/', '', 'uploads', @avatar_digest_path, 'avatar.jpg';

# Upload a file via plugin
my $path = $t->app->yancy->file->write( 'file.txt', $spec_asset );
is $path, $spec_url_path, 'correct url path returned (for name and asset)';
ok -e $spec_file_path, 'file exists (for name and asset)';
unlink $spec_file_path;

my $upload = Mojo::Upload->new( filename => 'file.txt', asset => $spec_asset );
$path = $t->app->yancy->file->write( $upload );
is $path, $spec_url_path, 'correct url path returned (for upload)';
ok -e $spec_file_path, 'file exists (for upload)';
unlink $spec_file_path;

# Upload a file via editor
$t->post_ok( '/yancy/upload', form => {
        upload => { content => $spec_asset->slurp, filename => 'file.txt' },
    } )
    ->status_is( 201 )
    ->header_is( Location => $spec_url_path )
    ->get_ok( $t->tx->res->headers->location )
    ->status_is( 200, 'file url exists' );
ok -e $spec_file_path, 'file exists'
    or diag join "\n", $root->list_tree->each;

# Upload a file via controller
$t->get_ok( '/user/' . $items{user}[0]{username} . '/edit' );
my $csrf_token = $t->tx->res->dom->at( 'form input[name=csrf_token]' )->attr( 'value' );
$t->post_ok( '/user/' . $items{user}[0]{username} . '/edit', form => {
        username => $items{user}[0]{username},
        email => $items{user}[0]{email},
        csrf_token => $csrf_token,
        avatar => { content => $avatar_asset->slurp, filename => 'avatar.jpg' },
    } )
    ->status_is( 302 )
    ->header_is( Location => '/user/' . $items{user}[0]{username} )
    ->get_ok( $t->tx->res->headers->location )
    ->status_is( 200 )
    ->text_is( h1 => 'doug' )
    ->element_exists(
        'img[src=' . $avatar_url_path . ']',
        'image has correct src attribute',
    )
    ->get_ok( $avatar_url_path )
    ->status_is( 200, 'image url exists' );
ok -e $avatar_file_path, 'file exists';

# Cleanup unlinked files
$t->app->yancy->file->cleanup( $backend );
ok !-e $spec_file_path, 'unlinked file is removed';
ok !-e $spec_file_path->dirname->dirname->dirname, 'digest directories removed';
ok -e $avatar_file_path, 'linked file still exists';

subtest 'test default file plugin' => sub {
    my $app = Mojolicious->new;
    $app->plugin( Yancy => {
        backend => $backend_url,
    } );
    ok $app->yancy->can( 'file' ), 'yancy.file helper exists';
    is $app->yancy->file->file_root, $app->home->child( 'public/uploads' ),
        'default file path is correct';
    is $app->yancy->file->url_root, '/uploads',
        'default url root is correct';
};

done_testing;
