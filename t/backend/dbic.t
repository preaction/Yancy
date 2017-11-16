
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
use Yancy::Backend::Dbic;

my $be;

subtest 'new' => sub {
    $be = Yancy::Backend::Dbic->new( 'dbic://Local::Schema/dbi:SQLite::memory:' );
    isa_ok $be, 'Yancy::Backend::Dbic';
    isa_ok $be->schema, 'Local::Schema';
};

my $schema = $be->schema;
$schema->deploy;

my %thing_one = (
    name => 'Thing One',
    email => 'one@example.com',
);
my $thing_one = $schema->resultset( 'People' )->create( \%thing_one );
$thing_one{ id } = $thing_one->id;

my %thing_two = (
    name => 'Thing Two',
    email => 'two@example.com',
);
my $thing_two = $schema->resultset( 'People' )->create( \%thing_two );
$thing_two{ id } = $thing_two->id;

subtest 'list' => sub {
    my $things = $be->list( 'People' );
    is_deeply $things, [ \%thing_one, \%thing_two ]
        or diag explain $things;
};

subtest 'get' => sub {
    my $got = $be->get( People => $thing_one{ id } );
    is_deeply $got, \%thing_one or diag explain $got;
};

subtest 'set' => sub {
    $thing_one{ name } = 'Thing Won';
    $be->set( People => $thing_one{ id } => \%thing_one );
    is $schema->resultset( 'People' )->find( $thing_one{ id } )->name,
        $thing_one{ name };
};

my %thing_three = (
    name => 'Thing Three',
    email => 'three@example.com',
);

subtest 'create' => sub {
    my $got = $be->create( People => \%thing_three );
    my $inserted = $schema->resultset( 'People' )->search({ name => 'Thing Three' })->first;
    $thing_three{ id } = $inserted->id;
    is_deeply $got, \%thing_three or diag explain $got;
};

subtest 'delete' => sub {
    $be->delete( People => $thing_three{ id } );
    ok !$schema->resultset( 'People' )->find( $thing_three{ id } ),
        'third person not found';
};

done_testing;
