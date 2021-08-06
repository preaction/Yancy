
=head1 DESCRIPTION

This test makes sure the L<DBIx::Class> backend works.

To run this test, you must have these modules and versions:

=over

=item * DBIx::Class (any version)

=item * DBD::SQLite (any version)

=item * SQL::Translator 0.11018 (to deploy the test schema)

=back

The test schema is located in C<t/lib/Local/Schema.pm>.

=head1 SEE ALSO

C<t/lib/Local/Test.pm>

=cut

use Mojo::Base '-strict';
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use Mojo::File qw( path tempfile );

BEGIN {
    eval { require DBIx::Class; DBIx::Class->VERSION( 0.082842 ); 1 }
        or plan skip_all => 'DBIx::Class >= 0.082842 required for this test';
    eval { require DBD::SQLite; 1 }
        or plan skip_all => 'DBD::SQLite required for this test';
    eval { require SQL::Translator; SQL::Translator->VERSION( 0.11018 ); 1 }
        or plan skip_all => 'SQL::Translator >= 0.11018 required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common );
use Yancy::Backend::Dbic;

my $schema = \%Yancy::Backend::Test::SCHEMA;

# Isolate test data, using automatic temporary on-disk database
# Also, make sure any backend we initialize with `init_backend` is the
# same backend
my $tempfile = tempfile();
my $dsn = 'dbi:SQLite:' . $tempfile;
my $backend_url = 'dbic://Local::Schema/' . $dsn;
local $ENV{TEST_YANCY_BACKEND} = $backend_url;
use Local::Schema;
my $dbic = Local::Schema->connect( $dsn );
$dbic->deploy;
my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Dbic->new( 'dbic://Local::Schema/dbi:SQLite::memory:', $schema );
    isa_ok $be, 'Yancy::Backend::Dbic';
    isa_ok $be->driver, 'Local::Schema';
    is_deeply $be->schema, $schema;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Dbic->new( $dbic, $schema );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->driver, 'Local::Schema';
        is_deeply $be->schema, $schema;
    };

    subtest 'new with arrayref' => sub {
        my @attr = (
            'Local::Schema',
            'dbi:SQLite::memory:',
            undef, undef,
            { PrintError => 1 },
        );
        my $be = Yancy::Backend::Dbic->new( \@attr, $schema );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->driver, 'Local::Schema';
        is_deeply $be->driver->storage->connect_info, \@attr, 'connect_info is correct';
        is_deeply $be->schema, $schema;
    };
};

sub insert_item {
    my ( $schema_name, %item ) = @_;
    my $id_field = $schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my $row = $dbic->resultset( $schema_name )->create( \%item );
    my $inserted_id = $row->id;
    if (
        ( !$item{ $id_field } and $schema->{ $schema_name }{properties}{ $id_field }{type} eq 'integer' ) ||
        ( $id_field ne 'id' and exists $schema->{ $schema_name }{properties}{id} )
    ) {
        $item{id} = $inserted_id;
    }
    return %item;
}

backend_common( $be, \&insert_item, $schema );

subtest 'class and table name differ' => sub {
    use Local::CamelSchema;
    my $tempfile = tempfile();
    my $dsn = 'dbi:SQLite:' . $tempfile;
    my $backend_url = 'dbic://Local::CamelSchema/' . $dsn;
    my $dbic = Local::CamelSchema->connect( $dsn );
    $dbic->deploy;
    my $be = Yancy::Backend::Dbic->new( $dbic );
    my $schema = $be->read_schema;

    ok $schema->{Addresses}, 'Addresses result class found';
    ok $schema->{Cities}, 'Cities result class found';
    is $schema->{Addresses}{properties}{city_id}{'x-foreign-key'},
        'Cities', 'x-foreign-key resolved correctly';
};

done_testing;
