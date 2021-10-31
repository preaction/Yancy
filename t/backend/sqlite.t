
=head1 DESCRIPTION

This tests the L<Yancy::Backend::Sqlite> module which uses
L<Mojo::SQLite> to connect to a SQLite database.

If L<Mojo::SQLite> version >= 3.005 is installed, this script will run.
Set the C<TEST_ONLINE_SQLITE> environment variable to a
L<Mojo::SQLite> connect string in order to save the database to disk
rather than a temporary location:

    $ export TEST_ONLINE_SQLITE=sqlite:/tmp/test.db

=head1 SEE ALSO

C<t/lib/Local/Test.pm>, L<Mojo::SQLite>, L<Yancy>

=cut

use Mojo::Base '-strict';
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use Mojo::File qw( path tempfile );

BEGIN {
    eval { require DBD::SQLite; DBD::SQLite->VERSION( 1.56 ); 1 }
        or plan skip_all => 'DBD::SQLite >= 1.56 required for this test';
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3.005 ); 1 }
        or plan skip_all => 'Mojo::SQLite >= 3.005 required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common load_fixtures init_backend );

use Mojo::SQLite;
# Isolate test data, using automatic temporary on-disk database
# c.f., https://metacpan.org/pod/DBD::SQLite#Database-Name-Is-A-File-Name
# unless TEST_ONLINE_SQLITE is set, in which case use that
# Also, make sure any backend we initialize with `init_backend` is the
# same backend
my $tempfile = tempfile();
my $backend_url = $ENV{TEST_ONLINE_SQLITE} //= 'sqlite:' . $tempfile;
local $ENV{TEST_YANCY_BACKEND} = $ENV{TEST_ONLINE_SQLITE};
my $mojodb = Mojo::SQLite->new( $backend_url );

my $ddl = path( $Bin, '..', 'schema', 'sqlite.sql' )->slurp;
$mojodb->db->query( $_ ) for grep /\S/, split /;/, $ddl;

my $schema = \%Local::Test::SCHEMA;

use Yancy::Backend::Sqlite;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Sqlite->new( '', $schema );
    isa_ok $be, 'Yancy::Backend::Sqlite';
    isa_ok $be->driver, 'Mojo::SQLite';
    is_deeply $be->schema, $schema;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Sqlite->new( $mojodb, $schema );
        isa_ok $be, 'Yancy::Backend::Sqlite';
        isa_ok $be->driver, 'Mojo::SQLite';
        is_deeply $be->schema, $schema;
    };

    subtest 'new with hashref' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
        );
        $be = Yancy::Backend::Sqlite->new( \%attr, $schema );
        isa_ok $be, 'Yancy::Backend::Sqlite';
        isa_ok $be->driver, 'Mojo::SQLite';
        is $be->driver->dsn, $attr{dsn}, 'dsn is correct';
        is_deeply $be->schema, $schema;
    };
};

# Override sqlite attribute with reference to instantiated db object from above
$be->driver( $mojodb );

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

    # XXX: Test non-primary composite keys
    # XXX: Mark columns with generated defaults and retrieve them, but
    # only if we have some surrogate key to use to uniquely identify the
    # new row...
};

done_testing;
