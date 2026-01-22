
=head1 DESCRIPTION

This test makes sure the backend helpers registered by L<Mojolicious::Plugin::Yancy>
work correctly.

=head1 SEE ALSO

L<Yancy::Backend::Memory>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Scalar::Util qw( blessed );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend load_fixtures );

my $schema = \%Local::Test::SCHEMA;

my %fixtures = load_fixtures( 'basic' );
$schema->{ $_ } = $fixtures{ $_ } for keys %fixtures;

my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
    people => [
        {
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        {
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    ],
    user => [
        {
            username => 'preaction',
            password => 'secret',
            email => 'doug@example.com',
        },
    ],
    blog => [
        {
            username => 'preaction',
            title => 'My first blog post',
            markdown => '# Hello, World',
        },
    ],
);
my $backend_class = blessed $backend;

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( Yancy => {
    backend => $backend_url,
    schema => $schema,
    read_schema => 1,
} );
# We must still set the envvar so Test::Mojo doesn't reset it to "fatal"
$t->app->log->level( $ENV{MOJO_LOG_LEVEL} = 'error' );

# do not log to std(out,err)
open my $logfh, '>', \my $logbuf;
$t->app->log->handle( $logfh );

subtest 'model' => sub {
    my $model = $t->app->yancy->model;
    isa_ok $model, 'Yancy::Model';
    my $schema = $t->app->yancy->model( 'people' );
    isa_ok $schema, 'Yancy::Model::Schema';
    is $schema->name, 'people', 'correct schema object returned';
};

done_testing;
