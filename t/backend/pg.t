
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
use File::Spec::Functions qw( catdir );

BEGIN {
    eval { require Mojo::Pg; Mojo::Pg->VERSION( 3 ); 1 }
        or plan skip_all => 'Mojo::Pg >= 3.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_PG to enable this test'
        unless $ENV{TEST_ONLINE_PG};
}

use Mojo::Pg;
# Isolate test data
my $pg = Mojo::Pg->new($ENV{TEST_ONLINE_PG})->search_path(['yancy_pg_test']);
$pg->db->query('DROP SCHEMA IF EXISTS yancy_pg_test CASCADE');
$pg->db->query('CREATE SCHEMA yancy_pg_test');

$pg->db->query('CREATE TABLE people ( id SERIAL, name VARCHAR, email VARCHAR )');

my $schema = {
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
    $be = Yancy::Backend::Pg->new( $ENV{TEST_ONLINE_PG}, $schema );
    isa_ok $be, 'Yancy::Backend::Pg';
    isa_ok $be->pg, 'Mojo::Pg';
    is_deeply $be->schema, $schema;
};

$be->pg( $pg );

my %thing_one = (
    name => 'Thing One',
    email => 'one@example.com',
);
$thing_one{ id } = $pg->db->insert( people => \%thing_one, { returning => 'id' } )->hash->{id};

my %thing_two = (
    name => 'Thing Two',
    email => 'two@example.com',
);
$thing_two{ id } = $pg->db->insert( people => \%thing_two, { returning => 'id' } )->hash->{id};

subtest 'list' => sub {
    my $things = $be->list( 'people' );
    is_deeply $things, [ \%thing_one, \%thing_two ]
        or diag explain $things;
};

subtest 'get' => sub {
    my $got = $be->get( people => $thing_one{ id } );
    is_deeply $got, \%thing_one or diag explain $got;
};

subtest 'set' => sub {
    $thing_one{ name } = 'Thing Won';
    $be->set( people => $thing_one{ id } => \%thing_one );
    is $pg->db->select( people => undef, { name => $thing_one{name} } )->hashes->first->{name},
        $thing_one{ name };
};

my %thing_three = (
    name => 'Thing Three',
    email => 'three@example.com',
);

subtest 'create' => sub {
    my $got = $be->create( people => \%thing_three );
    my $inserted = $pg->db->select( people => undef, { name => 'Thing Three' })->hash;
    $thing_three{ id } = $inserted->{id};
    is_deeply $got, \%thing_three or diag explain $got;
};

subtest 'delete' => sub {
    $be->delete( people => $thing_three{ id } );
    ok !$pg->db->select( people => undef, { id => $thing_three{ id } } )->rows,
        'third person not found';
};

done_testing;
