
=head1 DESCRIPTION

This tests the L<Yancy::Backend::Pg> module which uses L<Mojo::Pg> to
connect to a Postgres database.

Set the C<TEST_ONLINE_PG> environment variable to a L<Mojo::Pg> connect
string to run this script.

To make a local Postgres server:

    # In another terminal
    $ initdb db
    $ postgres -D db

    # In the current terminal
    $ createdb test
    $ export TEST_ONLINE_PG=postgres://localhost/test

=head1 SEE ALSO

C<t/lib/Local/Test.pm>, L<Mojo::Pg>, L<Yancy>

=cut

use Mojo::Base '-strict';
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );

BEGIN {
    eval { require Mojo::Pg; Mojo::Pg->VERSION( 3 ); 1 }
        or plan skip_all => 'Mojo::Pg >= 3.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_PG to enable this test'
        unless $ENV{TEST_ONLINE_PG};
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( test_backend );

use Mojo::Pg;
# Isolate test data
my $mojodb = Mojo::Pg->new($ENV{TEST_ONLINE_PG})->search_path(['yancy_pg_test']);
$mojodb->db->query('DROP SCHEMA IF EXISTS yancy_pg_test CASCADE');
$mojodb->db->query('CREATE SCHEMA yancy_pg_test');

$mojodb->db->query(
    q{CREATE TYPE access_level AS ENUM ( 'user', 'moderator', 'admin' )},
);
$mojodb->db->query(
    q{CREATE TABLE people (
        id SERIAL PRIMARY KEY,
        name VARCHAR NOT NULL,
        email VARCHAR UNIQUE
    )}
);
$mojodb->db->query(
    q{CREATE TABLE "user" (
        username VARCHAR PRIMARY KEY,
        email VARCHAR NOT NULL,
        access access_level NOT NULL DEFAULT 'user',
        created TIMESTAMP DEFAULT '2018-03-01 00:00:00'
    )}
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

use Yancy::Backend::Pg;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Pg->new( $ENV{TEST_ONLINE_PG}, $collections );
    isa_ok $be, 'Yancy::Backend::Pg';
    isa_ok $be->mojodb, 'Mojo::Pg';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Pg->new( $mojodb, $collections );
        isa_ok $be, 'Yancy::Backend::Pg';
        isa_ok $be->mojodb, 'Mojo::Pg';
        is_deeply $be->collections, $collections;
    };

    subtest 'new with hashref' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
            username => $mojodb->username,
            password => $mojodb->password,
            search_path => $mojodb->search_path,
        );
        $be = Yancy::Backend::Pg->new( \%attr, $collections );
        isa_ok $be, 'Yancy::Backend::Pg';
        isa_ok $be->mojodb, 'Mojo::Pg';
        is $be->mojodb->dsn, $attr{dsn}, 'dsn is correct';
        is $be->mojodb->username, $attr{username}, 'username is correct';
        is $be->mojodb->password, $attr{password}, 'password is correct';
        is_deeply $be->collections, $collections;
    };
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $id = $mojodb->db->insert( $coll => \%item, { returning => $id_field } )->hash->{$id_field};
    $item{ $id_field } = $id;
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
    access => 'user',
    created => '2018-03-01 00:00:00',
);

subtest 'custom id field' => \&test_backend, $be,
    user => $collections->{ user }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { email => 'test@example.com' }, # Set test
    ;

done_testing;
