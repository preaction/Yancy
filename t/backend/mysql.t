
=head1 DESCRIPTION

This tests the L<Yancy::Backend::Mysql> module which uses L<Mojo::mysql>
to connect to a MySQL database.

Set the C<TEST_ONLINE_MYSQL> environment variable to a L<Mojo::mysql>
connect string to run this script.

To make a local MySQL server:

    # In another terminal
    $ mysqld --initialize --datadir=db
    $ mysqld --skip-grant-tables --datadir=db

    # In the current terminal
    $ mysqladmin create yancy_mysql_test
    $ export TEST_ONLINE_MYSQL=mysql://localhost/yancy_mysql_test

B<NOTE>: The only way to kill the MySQL from the other terminal is to
use C<kill(1)> from the first terminal.

=head1 SEE ALSO

C<t/lib/Local/Test.pm>, L<Mojo::mysql>, L<Yancy>

=cut

use Mojo::Base '-strict';
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use Mojo::File qw( path );

BEGIN {
    eval { require Mojo::mysql; Mojo::mysql->VERSION( 1 ); 1 }
        or plan skip_all => 'Mojo::mysql >= 1.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_MYSQL to enable this test'
        unless $ENV{TEST_ONLINE_MYSQL};
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common init_backend load_fixtures );

use Mojo::mysql;
# Isolate test data.  Also, make sure any backend we initialize with
# `init_backend` is the same backend
local $ENV{TEST_YANCY_BACKEND} = my $backend_url = $ENV{TEST_ONLINE_MYSQL};
my $mojodb = Mojo::mysql->new( $backend_url );

$mojodb->db->query('DROP DATABASE IF EXISTS yancy_mysql_test');
$mojodb->db->query('CREATE DATABASE yancy_mysql_test');
$mojodb->db->query('USE yancy_mysql_test');

my $ddl = path( $Bin, '..', 'schema', 'mysql.sql' )->slurp;
$mojodb->db->query( $_ ) for grep /\S/, split /;/, $ddl;

my $schema = \%Yancy::Backend::Test::SCHEMA;

use Yancy::Backend::Mysql;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Mysql->new( $ENV{TEST_ONLINE_MYSQL}, $schema );
    isa_ok $be, 'Yancy::Backend::Mysql';
    isa_ok $be->driver, 'Mojo::mysql';
    is_deeply $be->schema, $schema;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Mysql->new( $mojodb, $schema );
        isa_ok $be, 'Yancy::Backend::Mysql';
        isa_ok $be->driver, 'Mojo::mysql';
        is_deeply $be->schema, $schema;
    };

    subtest 'new with attributes' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
            username => $mojodb->username,
            password => $mojodb->password,
        );
        $be = Yancy::Backend::Mysql->new( \%attr, $schema );
        isa_ok $be, 'Yancy::Backend::Mysql';
        isa_ok $be->driver, 'Mojo::mysql';
        is_deeply $be->schema, $schema;
    };
};

sub insert_item {
    my ( $schema_name, %item ) = @_;
    my $id_field = $schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my $inserted_id = $mojodb->db->insert( $schema_name => \%item )->last_insert_id;
    if (
        ( !$item{ $id_field } and $schema->{ $schema_name }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $schema->{ $schema_name }{properties}{id} )
    ) {
        $item{id} = $inserted_id;
    }
    return %item;
}

backend_common( $be, \&insert_item, $schema );

subtest 'composite key' => sub {
    my %schema = load_fixtures( 'composite-key' );
    my ( $backend_url, $be ) = init_backend( \%schema );
    my %required = (
        title => 'Decapod 10',
        slug => 'Decapod_10',
        content => 'A bit of a schlep',
    );
    eval { $be->create( wiki_pages => { %required } ) };
    ok $@, 'create() without all composite key parts dies';
    eval { $be->create( wiki_pages => { %required, wiki_page_id => 1 } ) };
    ok $@, 'create() without all composite key parts dies';
    eval { $be->create( wiki_pages => { %required, revision_date => '2020-01-01' } ) };
    ok $@, 'create() without all composite key parts dies';
};

done_testing;
