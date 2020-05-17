
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
use Mojo::File qw( path );

BEGIN {
    eval { require Mojo::Pg; Mojo::Pg->VERSION( 3 ); 1 }
        or plan skip_all => 'Mojo::Pg >= 3.0 required for this test';
    plan skip_all => 'set TEST_ONLINE_PG to enable this test'
        unless $ENV{TEST_ONLINE_PG};
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common init_backend load_fixtures );

use Mojo::Pg;
# Isolate test data.  Also, make sure any backend we initialize with
# `init_backend` is the same backend
local $ENV{TEST_YANCY_BACKEND} = my $backend_url = $ENV{TEST_ONLINE_PG};
$ENV{TEST_YANCY_BACKEND} =~ s/^postgres/pg/;
my $mojodb = Mojo::Pg->new( $backend_url )->search_path(['yancy_pg_test']);
$mojodb->db->query('DROP SCHEMA IF EXISTS yancy_pg_test CASCADE');
$mojodb->db->query('CREATE SCHEMA yancy_pg_test');

my $ddl = path( $Bin, '..', 'schema', 'pg.sql' )->slurp;
$mojodb->db->query( $_ ) for grep /\S/, split /;/, $ddl;

my $schema = \%Yancy::Backend::Test::SCHEMA;

use Yancy::Backend::Pg;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Pg->new( $ENV{TEST_ONLINE_PG}, $schema );
    isa_ok $be, 'Yancy::Backend::Pg';
    isa_ok $be->mojodb, 'Mojo::Pg';
    is_deeply $be->schema, $schema;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Pg->new( $mojodb, $schema );
        isa_ok $be, 'Yancy::Backend::Pg';
        isa_ok $be->mojodb, 'Mojo::Pg';
        is_deeply $be->schema, $schema;
    };

    subtest 'new with hashref' => sub {
        my %attr = (
            dsn => $mojodb->dsn,
            username => $mojodb->username,
            password => $mojodb->password,
            search_path => $mojodb->search_path,
        );
        $be = Yancy::Backend::Pg->new( \%attr, $schema );
        isa_ok $be, 'Yancy::Backend::Pg';
        isa_ok $be->mojodb, 'Mojo::Pg';
        is $be->mojodb->dsn, $attr{dsn}, 'dsn is correct';
        is $be->mojodb->username, $attr{username}, 'username is correct';
        is $be->mojodb->password, $attr{password}, 'password is correct';
        is_deeply $be->schema, $schema;
    };
};

sub insert_item {
    my ( $schema_name, %item ) = @_;
    my $id_field = $schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my $inserted_id = $mojodb->db->insert( $schema_name => \%item, { returning => 'id' } )->hash->{id};
    if (
        ( !$item{ $id_field } and $schema->{ $schema_name }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $schema->{ $schema_name }{properties}{id} )
    ) {
        $item{id} = $inserted_id;
    }
    return %item;
}

backend_common( $be, \&insert_item, $schema );

subtest 'composite key' => sub {
    my %schema = load_fixtures( 'composite-key' );
    my ( $backend_url, $be ) = init_backend( \%schema );
    my %required = (
        title => 'Decapod 10',
        slug => 'Decapod_10',
        content => 'A bit of a schlep',
    );
    my $id;
    eval { $id = $be->create( wiki_pages => { %required } ) };
    ok !$@, 'create() without all composite key parts does not die'
        or diag $@;
    like $id->{wiki_page_id}, qr{^\d+$}, 'wiki_page_id looks like a number';
    like $id->{revision_date}, qr{^\d{4}-\d{2}-\d{2}}, 'revision_date looks like a date';
};

done_testing;
