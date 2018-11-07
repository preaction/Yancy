
=head1 DESCRIPTION

This test makes sure the L<DBIx::Class> backend works.

To run this test, you must have these modules and versions:

=over

=item * DBIx::Class (any version)

=item * DBD::SQLite (any version)

=item * SQL::Translator 0.11018 (to deploy the test schema.

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
use Local::Test qw( test_backend );
use Yancy::Backend::Dbic;

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
            username => {
                type => 'string',
            },
        },
    },
    mojo_migrations => {
        'x-ignore' => 1,
    },
};

use Local::BackendTestSchema;
my $dbic = Local::BackendTestSchema->connect( 'dbi:SQLite::memory:' );
$dbic->deploy;
my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Dbic->new( 'dbic://Local::BackendTestSchema/dbi:SQLite::memory:', $collections );
    isa_ok $be, 'Yancy::Backend::Dbic';
    isa_ok $be->dbic, 'Local::BackendTestSchema';
    is_deeply $be->collections, $collections;

    subtest 'new with connection' => sub {
        $be = Yancy::Backend::Dbic->new( $dbic, $collections );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->dbic, 'Local::BackendTestSchema';
        is_deeply $be->collections, $collections;
    };

    subtest 'new with arrayref' => sub {
        my @attr = (
            'Local::BackendTestSchema',
            'dbi:SQLite::memory:',
            undef, undef,
            { PrintError => 1 },
        );
        my $be = Yancy::Backend::Dbic->new( \@attr, $collections );
        isa_ok $be, 'Yancy::Backend::Dbic';
        isa_ok $be->dbic, 'Local::BackendTestSchema';
        is_deeply $be->dbic->storage->connect_info, \@attr, 'connect_info is correct';
        is_deeply $be->collections, $collections;
    };
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $row = $dbic->resultset( $coll )->create( \%item );
    $item{ $id_field } ||= $row->$id_field;
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
    { name => 'Set' }, # Set test
    ;

my %user_one = insert_item( 'user',
    username => 'one',
    email => 'one@example.com',
    access => 'user',
    created => '2018-03-01 00:00:00',
);
my %user_two = insert_item( 'user',
    username => 'two',
    email => 'two@example.com',
    access => 'moderator',
    created => '2018-03-01 00:00:00',
);
my %user_three = (
    username => 'three',
    email => 'three@example.com',
    access => 'admin',
    created => '2018-03-01 00:00:00',
);

subtest 'custom id field' => \&test_backend, $be,
    user => $collections->{ user }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { email => 'test@example.com' }, # Set test
    ;

done_testing;
