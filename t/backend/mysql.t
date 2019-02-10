
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
use Local::Test qw( backend_common );

use Mojo::mysql;
# Isolate test data
my $mojodb = Mojo::mysql->new($ENV{TEST_ONLINE_MYSQL});

$mojodb->db->query('DROP DATABASE IF EXISTS yancy_mysql_test');
$mojodb->db->query('CREATE DATABASE yancy_mysql_test');
$mojodb->db->query('USE yancy_mysql_test');

my $ddl = path( $Bin, '..', 'schema', 'mysql.sql' )->slurp;
$mojodb->db->query( $_ ) for grep /\S/, split /;/, $ddl;

my $collections = \%Yancy::Backend::Test::SCHEMA;

use Yancy::Backend::Mysql;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Mysql->new( $ENV{TEST_ONLINE_MYSQL}, $collections );
    isa_ok $be, 'Yancy::Backend::Mysql';
    isa_ok $be->mojodb, 'Mojo::mysql';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Mysql->new( $mojodb, $collections );
        isa_ok $be, 'Yancy::Backend::Mysql';
        isa_ok $be->mojodb, 'Mojo::mysql';
        is_deeply $be->collections, $collections;
    };

    subtest 'new with attributes' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
            username => $mojodb->username,
            password => $mojodb->password,
        );
        $be = Yancy::Backend::Mysql->new( \%attr, $collections );
        isa_ok $be, 'Yancy::Backend::Mysql';
        isa_ok $be->mojodb, 'Mojo::mysql';
        is_deeply $be->collections, $collections;
    };
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $id = $mojodb->db->insert( $coll => \%item )->last_insert_id;
    $item{ $id_field } ||= $id;
    return %item;
}

backend_common( $be, \&insert_item, $collections );

done_testing;
