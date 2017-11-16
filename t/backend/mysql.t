
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

L<Mojo::mysql>, L<Yancy>

=cut

use v5.24;
use experimental qw( signatures postderef );
use Test::More;
use File::Spec::Functions qw( catdir );

BEGIN {
    eval { require Mojo::mysql; Mojo::mysql->VERSION( 1 ); 1 }
        or plan skip_all => 'Mojo::mysql >= 1.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_MYSQL to enable this test'
        unless $ENV{TEST_ONLINE_MYSQL};
}

use Mojo::mysql;
# Isolate test data
my $mysql = Mojo::mysql->new($ENV{TEST_ONLINE_MYSQL});
$mysql->db->query('DROP DATABASE IF EXISTS yancy_mysql_test');
$mysql->db->query('CREATE DATABASE yancy_mysql_test');
$mysql->db->query('USE yancy_mysql_test');

$mysql->db->query('CREATE TABLE people ( id INTEGER AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), `email` VARCHAR(255) )');

use Yancy::Backend::Mysql;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Mysql->new( $ENV{TEST_ONLINE_MYSQL} );
    isa_ok $be, 'Yancy::Backend::Mysql';
    isa_ok $be->mysql, 'Mojo::mysql';
};

$be->mysql( $mysql );

my %thing_one = (
    name => 'Thing One',
    email => 'one@example.com',
);
$mysql->db->insert( people => \%thing_one );
$thing_one{ id } = $mysql->db->select( people => undef, { name => $thing_one{ name } } )->hash->{id};

my %thing_two = (
    name => 'Thing Two',
    email => 'two@example.com',
);
$mysql->db->insert( people => \%thing_two );
$thing_two{ id } = $mysql->db->select( people => undef, { name => $thing_two{ name } } )->hash->{id};

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
    is $mysql->db->select( people => undef, { name => $thing_one{name} } )->hashes->first->{name},
        $thing_one{ name };
};

my %thing_three = (
    name => 'Thing Three',
    email => 'three@example.com',
);

subtest 'create' => sub {
    my $got = $be->create( people => \%thing_three );
    my $inserted = $mysql->db->select( people => undef, { name => 'Thing Three' })->hash;
    $thing_three{ id } = $inserted->{id};
    is_deeply $got, \%thing_three or diag explain $got;
};

subtest 'delete' => sub {
    $be->delete( people => $thing_three{ id } );
    ok !$mysql->db->select( people => undef, { id => $thing_three{ id } } )->rows,
        'third person not found';
};

done_testing;
