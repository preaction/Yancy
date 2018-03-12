
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

$mysql->db->query(
    'CREATE TABLE people (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        `email` VARCHAR(255)
    )',
);
$mysql->db->query(
    q{CREATE TABLE `user` (
        `username` VARCHAR(255) PRIMARY KEY,
        `email` VARCHAR(255) NOT NULL,
        `access` ENUM ( 'user', 'moderator', 'admin' ) NOT NULL DEFAULT 'user'
    )},
);
$mysql->db->query(q{
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

use Yancy::Backend::Mysql;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Mysql->new( $ENV{TEST_ONLINE_MYSQL}, $collections );
    isa_ok $be, 'Yancy::Backend::Mysql';
    isa_ok $be->mysql, 'Mojo::mysql';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Mysql->new( $mysql, $collections );
        isa_ok $be, 'Yancy::Backend::Mysql';
        isa_ok $be->mysql, 'Mojo::mysql';
        is_deeply $be->collections, $collections;
    };
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $id = $mysql->db->insert( $coll => \%item )->last_insert_id;
    $item{ $id_field } ||= $id;
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

my %user_one = insert_item( 'user',
    username => 'one',
    email => 'one@example.com',
    access => 'user',
);
my %user_two = insert_item( 'user',
    username => 'two',
    email => 'two@example.com',
    access => 'moderator',
);
my %user_three = (
    username => 'three',
    email => 'three@example.com',
    access => 'admin',
);

subtest 'custom id field' => \&test_backend, $be,
    user => $collections->{ user }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { %user_three, email => 'test@example.com' }, # Set test
    ;

done_testing;
