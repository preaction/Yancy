
=head1 DESCRIPTION

This tests the L<Yancy::Backend::Sqlite> module which uses
L<Mojo::SQLite> to connect to a SQLite database.

If L<Mojo::SQLite> version >= 3 is installed, this script will run.
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

BEGIN {
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3 ); 1 }
        or plan skip_all => 'Mojo::SQLite >= 3.0 required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( test_backend );

use Mojo::SQLite;
# Isolate test data, using automatic temporary on-disk database
# c.f., https://metacpan.org/pod/DBD::SQLite#Database-Name-Is-A-File-Name
# unless TEST_ONLINE_SQLITE is set, in which case use that

my $mojodb = Mojo::SQLite->new($ENV{TEST_ONLINE_SQLITE});

$mojodb->db->query(
    'CREATE TABLE people (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE
    )',
);
$mojodb->db->query(
    q{CREATE TABLE "user" (
        username VARCHAR(255) PRIMARY KEY,
        email VARCHAR(255) NOT NULL,
        access TEXT NOT NULL CHECK( access IN ('user', 'moderator', 'admin') ) DEFAULT 'user',
        created TIMESTAMP DEFAULT '2018-03-01 00:00:00'
    )},
);
$mojodb->db->query(q{
    CREATE TABLE mojo_migrations (
        name VARCHAR(255) UNIQUE NOT NULL,
        version INTEGER NOT NULL
    )
});

my $collections = {
    people => {
        type => 'object',
        properties => {
            id => {
                type => 'integer',
            },
            name => {
                type => 'string',
            },
            email => {
                type => 'string',
                pattern => '^[^@]+@[^@]+$',
            },
        },
    },
    user => {
        type => 'object',
        'x-id-field' => 'username',
        properties => {
            username => { type => 'string' },
            email => { type => 'string' },
        },
    },
};

use Yancy::Backend::Sqlite;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Sqlite->new( '', $collections );
    isa_ok $be, 'Yancy::Backend::Sqlite';
    isa_ok $be->mojodb, 'Mojo::SQLite';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Sqlite->new( $mojodb, $collections );
        isa_ok $be, 'Yancy::Backend::Sqlite';
        isa_ok $be->mojodb, 'Mojo::SQLite';
        is_deeply $be->collections, $collections;
    };

    subtest 'new with hashref' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
        );
        $be = Yancy::Backend::Sqlite->new( \%attr, $collections );
        isa_ok $be, 'Yancy::Backend::Sqlite';
        isa_ok $be->mojodb, 'Mojo::SQLite';
        is $be->mojodb->dsn, $attr{dsn}, 'dsn is correct';
        is_deeply $be->collections, $collections;
    };
};

# Override sqlite attribute with reference to instantiated db object from above
$be->mojodb( $mojodb );

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $inserted_id = $mojodb->db->insert( $coll => \%item )->last_insert_id;
    # SQLite does not have a 'returning' syntax. Assume ID is stored
    # if passed, computed if undef:
    $item{ $id_field } //= $inserted_id;
    return %item;
}

my %person_one = insert_item( people =>
    name => 'person One',
    email => 'one@example.com',
);

my %person_two = insert_item( people =>
    name => 'person Two',
    email => 'two@example.com',
);

my %person_three = (
    name => 'person Three',
    email => 'three@example.com',
);

subtest 'default id field' => \&test_backend, $be,
    people => $collections->{ people }, # Collection
    [ \%person_one, \%person_two ], # List (already in backend)
    \%person_three, # Create/Delete test
    { name => 'Set' }, # Set test
    ;

my %user_one = insert_item( 'user',
    username => 'one',
    email => 'one@example.com',
    access => 'user',
    created => '2018-03-01 00:00:00',
);
my %user_two = insert_item( 'user',
    username => 'two',
    email => 'two@example.com',
    access => 'moderator',
    created => '2018-03-01 00:00:00',
);
my %user_three = (
    username => 'three',
    email => 'three@example.com',
    access => 'admin',
    created => '2018-03-01 00:00:00',
);

subtest 'custom id field' => \&test_backend, $be,
    user => $collections->{ user }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { email => 'test@example.com' }, # Set test
    ;

done_testing;
