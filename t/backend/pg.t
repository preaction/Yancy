
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

use v5.24;
use experimental qw( signatures postderef );
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
my $pg = Mojo::Pg->new($ENV{TEST_ONLINE_PG})->search_path(['yancy_pg_test']);
$pg->db->query('DROP SCHEMA IF EXISTS yancy_pg_test CASCADE');
$pg->db->query('CREATE SCHEMA yancy_pg_test');

$pg->db->query('CREATE TABLE people ( id SERIAL, name VARCHAR, email VARCHAR )');
$pg->db->query('CREATE TABLE "user" ( username VARCHAR PRIMARY KEY, email VARCHAR )');

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
    isa_ok $be->pg, 'Mojo::Pg';
    is_deeply $be->collections, $collections;
};

$be->pg( $pg );

sub insert_item( $coll, %item ) {
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $id = $pg->db->insert( $coll => \%item, { returning => $id_field } )->hash->{$id_field};
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
    { %person_three, name => 'Set' }, # Set test
    ;

my %user_one = insert_item( 'user', username => 'one', email => 'one@example.com' );
my %user_two = insert_item( 'user', username => 'two', email => 'two@example.com' );
my %user_three = ( username => 'three', email => 'three@example.com' );

subtest 'custom id field' => \&test_backend, $be,
    user => $collections->{ user }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { %user_three, email => 'test@example.com' }, # Set test
    ;

done_testing;
