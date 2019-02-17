
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

BEGIN {
    eval { require DBIx::Class; 1 }
        or plan skip_all => 'DBIx::Class required for this test';
    eval { require DBD::SQLite; 1 }
        or plan skip_all => 'DBD::SQLite required for this test';
    eval { require SQL::Translator; SQL::Translator->VERSION( 0.11018 ); 1 }
        or plan skip_all => 'SQL::Translator >= 0.11018 required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common );
use Yancy::Backend::Dbic;

my $collections = \%Yancy::Backend::Test::SCHEMA;

use Local::Schema;
my $dbic = Local::Schema->connect( 'dbi:SQLite::memory:' );
$dbic->deploy;
my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Dbic->new( 'dbic://Local::Schema/dbi:SQLite::memory:', $collections );
    isa_ok $be, 'Yancy::Backend::Dbic';
    isa_ok $be->dbic, 'Local::Schema';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Dbic->new( $dbic, $collections );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->dbic, 'Local::Schema';
        is_deeply $be->collections, $collections;
    };

    subtest 'new with arrayref' => sub {
        my @attr = (
            'Local::Schema',
            'dbi:SQLite::memory:',
            undef, undef,
            { PrintError => 1 },
        );
        my $be = Yancy::Backend::Dbic->new( \@attr, $collections );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->dbic, 'Local::Schema';
        is_deeply $be->dbic->storage->connect_info, \@attr, 'connect_info is correct';
        is_deeply $be->collections, $collections;
    };
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $row = $dbic->resultset( $coll )->create( \%item );
    my $inserted_id = $row->id;
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
