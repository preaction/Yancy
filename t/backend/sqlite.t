
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
use Mojo::File qw( path );

BEGIN {
    eval { require Mojo::SQLite; Mojo::SQLite->VERSION( 3 ); 1 }
        or plan skip_all => 'Mojo::SQLite >= 3.0 required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common );

use Mojo::SQLite;
# Isolate test data, using automatic temporary on-disk database
# c.f., https://metacpan.org/pod/DBD::SQLite#Database-Name-Is-A-File-Name
# unless TEST_ONLINE_SQLITE is set, in which case use that

my $mojodb = Mojo::SQLite->new($ENV{TEST_ONLINE_SQLITE});

my $ddl = path( $Bin, '..', 'schema', 'sqlite.sql' )->slurp;
$mojodb->db->query( $_ ) for grep /\S/, split /;/, $ddl;

my $collections = \%Yancy::Backend::Test::SCHEMA;

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
    if (
        ( !$item{ $id_field } and $collections->{ $coll }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $collections->{ $coll }{properties}{id} )
    ) {
        $item{id} = $inserted_id;
    }
    return %item;
}

backend_common( $be, \&insert_item, $collections );

done_testing;
