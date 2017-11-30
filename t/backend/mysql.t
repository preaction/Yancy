
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
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );

BEGIN {
    eval { require Mojo::mysql; Mojo::mysql->VERSION( 1 ); 1 }
        or plan skip_all => 'Mojo::mysql >= 1.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_MYSQL to enable this test'
        unless $ENV{TEST_ONLINE_MYSQL};
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( test_backend );

use Mojo::mysql;
# Isolate test data
my $mysql = Mojo::mysql->new($ENV{TEST_ONLINE_MYSQL});
$mysql->db->query('DROP DATABASE IF EXISTS yancy_mysql_test');
$mysql->db->query('CREATE DATABASE yancy_mysql_test');
$mysql->db->query('USE yancy_mysql_test');

$mysql->db->query('CREATE TABLE people ( id INTEGER AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), `email` VARCHAR(255) )');

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

use Yancy::Backend::Mysql;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Mysql->new( $ENV{TEST_ONLINE_MYSQL}, $collections );
    isa_ok $be, 'Yancy::Backend::Mysql';
    isa_ok $be->mysql, 'Mojo::mysql';
    is_deeply $be->collections, $collections;
};

$be->mysql( $mysql );

my %person_one = (
    name => 'person One',
    email => 'one@example.com',
);
$mysql->db->insert( people => \%person_one );
$person_one{ id } = $mysql->db->select( people => undef, { name => $person_one{ name } } )->hash->{id};

my %person_two = (
    name => 'person Two',
    email => 'two@example.com',
);
$mysql->db->insert( people => \%person_two );
$person_two{ id } = $mysql->db->select( people => undef, { name => $person_two{ name } } )->hash->{id};

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
