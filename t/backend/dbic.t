
use v5.24;
use experimental qw( signatures postderef );
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );

BEGIN {
    eval { require DBIx::Class; 1 }
        or plan skip_all => 'DBIx::Class required for this test';
    eval { require DBD::SQLite; 1 }
        or plan skip_all => 'DBD::SQLite required for this test';
}

use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( test_backend );
use Yancy::Backend::Dbic;

my $collections = {
    People => {
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
    User => {
        type => 'object',
        'x-id-field' => 'username',
        properties => {
            username => {
                type => 'string',
            },
        },
    },
};

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Dbic->new( 'dbic://Local::Schema/dbi:SQLite::memory:', $collections );
    isa_ok $be, 'Yancy::Backend::Dbic';
    isa_ok $be->dbic, 'Local::Schema';
    is_deeply $be->collections, $collections;
};

my $dbic = $be->dbic;
$dbic->deploy;

my %person_one = (
    name => 'person One',
    email => 'one@example.com',
);
my $person_one = $dbic->resultset( 'People' )->create( \%person_one );
$person_one{ id } = $person_one->id;

my %person_two = (
    name => 'person Two',
    email => 'two@example.com',
);
my $person_two = $dbic->resultset( 'People' )->create( \%person_two );
$person_two{ id } = $person_two->id;

my %person_three = (
    name => 'person Three',
    email => 'three@example.com',
);

subtest 'default id field' => \&test_backend, $be,
    People => $collections->{ People }, # Collection
    [ \%person_one, \%person_two ], # List (already in backend)
    \%person_three, # Create/Delete test
    { %person_three, name => 'Set' }, # Set test
    ;

done_testing;
