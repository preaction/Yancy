
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

L<Mojo::Pg>, L<Yancy>

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

my %person_one = (
    name => 'person One',
    email => 'one@example.com',
);
$person_one{ id } = $pg->db->insert( people => \%person_one, { returning => 'id' } )->hash->{id};

my %person_two = (
    name => 'person Two',
    email => 'two@example.com',
);
$person_two{ id } = $pg->db->insert( people => \%person_two, { returning => 'id' } )->hash->{id};

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

done_testing;
