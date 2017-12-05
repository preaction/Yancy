
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
    eval { require SQL::Translator; SQL::Translator->VERSION( 0.11018 ); 1 }
        or plan skip_all => 'SQL::Translator >= 0.11018 required for this test';
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

sub insert_item( $coll, %item ) {
    my $id_field = $collections->{ $coll }{ 'x-id-field' } || 'id';
    my $row = $dbic->resultset( $coll )->create( \%item );
    $item{ $id_field } ||= $row->$id_field;
    return %item;
}

my %person_one = insert_item( People =>
    name => 'person One',
    email => 'one@example.com',
);

my %person_two = insert_item( People =>
    name => 'person Two',
    email => 'two@example.com',
);

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

my %user_one = insert_item( 'User', username => 'one', email => 'one@example.com' );
my %user_two = insert_item( 'User', username => 'two', email => 'two@example.com' );
my %user_three = ( username => 'three', email => 'three@example.com' );

subtest 'custom id field' => \&test_backend, $be,
    User => $collections->{ User }, # Collection
    [ \%user_one, \%user_two ], # List (already in backend)
    \%user_three, # Create/Delete test
    { %user_three, email => 'test@example.com' }, # Set test
    ;

done_testing;
