
=head1 DESCRIPTION

This test makes sure the backend helpers registered by L<Mojolicious::Plugin::Yancy>
work correctly.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use v5.24;
use experimental qw( signatures postderef );
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Scalar::Util qw( blessed );
use lib "".path( $Bin, 'lib' );

use Yancy::Backend::Test;
%Yancy::Backend::Test::COLLECTIONS = (
    people => {
        1 => {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        2 => {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    },
    users => {
        doug => {
            username => 'doug',
            email => 'doug@example.com',
        },
        joel => {
            username => 'joel',
            email => 'joel@example.com',
        },
    },
);

$ENV{MOJO_CONFIG} = path( $Bin, '/share/config.pl' );

my $t = Test::Mojo->new( 'Yancy' );
$t->app->yancy->filter->add( foobar => sub { 'foobar' } );
$t->app->config->{collections}{people}{properties}{foobar} = {
    type => 'string',
    'x-filter' => [ 'foobar' ],
};

subtest 'list' => sub {
    my @got_list = $t->app->yancy->list( 'people' );
    is_deeply
        \@got_list,
        [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 1 2 )} ]
            or diag explain \@got_list;

    @got_list = $t->app->yancy->list( 'people', {}, { limit => 1, offset => 1 } );
    is_deeply
        \@got_list,
        [ $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 2 )} ]
            or diag explain \@got_list;
};

subtest 'get' => sub {
    my $got = $t->app->yancy->get( people => 1 );
    is_deeply
        $got,
        $Yancy::Backend::Test::COLLECTIONS{people}->@{qw( 1 )}
            or diag explain $got;
};

subtest 'set' => sub {
    my $new_person = { name => 'Foo', email => 'doug@example.com', id => 1 };
    $t->app->yancy->set( people => 1 => { $new_person->%* });
    $new_person->{foobar} = 'foobar'; # filters are executed
    is_deeply $Yancy::Backend::Test::COLLECTIONS{people}{1}, $new_person;

    subtest 'set dies with missing fields' => sub {
        eval { $t->app->yancy->set( people => 1 => {} ) };
        ok $@, 'set() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        is_deeply $Yancy::Backend::Test::COLLECTIONS{people}{1}, $new_person,
            'person is not saved';
    };
};

subtest 'create' => sub {
    my $new_person = { name => 'Bar', email => 'bar@example.com' };
    $t->app->yancy->create( people => { $new_person->%* });
    $new_person->{foobar} = 'foobar'; # filters are executed
    $new_person->{id} = 3;
    is_deeply $Yancy::Backend::Test::COLLECTIONS{people}{3}, $new_person;

    my $count = scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*;
    subtest 'create dies with missing fields' => sub {
        eval { $t->app->yancy->create( people => {} ) };
        ok $@, 'create() dies';
        is blessed $@->[0], 'JSON::Validator::Error' or diag explain $@;
        is scalar keys $Yancy::Backend::Test::COLLECTIONS{people}->%*,
            $count, 'no new person was added';
    };
};

subtest 'delete' => sub {
    $t->app->yancy->delete( people => 3 );
    ok !exists $Yancy::Backend::Test::COLLECTIONS{people}{3}, 'person 3 not exists';
};

done_testing;
