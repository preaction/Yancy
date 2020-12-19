
=head1 DESCRIPTION

This tests the configuration phase of Yancy, and any errors that could
occur (like missing ID fields).

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Yancy;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );
use Mojo::JSON qw( true );

BEGIN { $ENV{MOJO_HOME} = "".path( $Bin ); } # avoid local yancy.conf

my $schema_micro = \%Yancy::Backend::Test::SCHEMA_MICRO;

my ( $backend_url, $backend, %items ) = init_backend( {} );

subtest 'read_schema' => sub {

    subtest 'schema completely from database' => sub {
        my $app = Yancy->new(
            config => {
                read_schema => 1,
                backend => $backend_url,
                schema => $schema_micro,
                editor => { require_user => undef, },
            },
        );

        is_deeply $app->yancy->schema( 'people' ),
            {
                type => 'object',
                required => [qw( name )],
                properties => {
                    id => {
                        'x-order' => 1,
                        readOnly => true,
                        type => 'integer',
                    },
                    name => {
                        'x-order' => 2,
                        type => 'string',
                    },
                    email => {
                        'x-order' => 3,
                        type => [ 'string', 'null' ],
                    },
                    age => {
                        type => [qw( integer null )],
                        'x-order' => 4,
                    },
                    contact => {
                        type => [qw( boolean null )],
                        default => 0,
                        'x-order' => 5,
                    },
                    phone => {
                        type => [qw( string null )],
                        'x-order' => 6,
                    },
                },
            },
            'people schema read from database'
                or diag explain $app->yancy->schema( 'people' );

        is_deeply $app->yancy->schema( 'user' ),
            {
                type => 'object',
                required => [qw( username email password )],
                'x-id-field' => 'username',
                'x-list-columns' => [qw( username email )],
                properties => {
                    id => {
                        'x-order' => 1,
                        readOnly => true,
                        type => 'integer',
                    },
                    username => {
                        'x-order' => 2,
                        type => 'string',
                    },
                    email => {
                        'x-order' => 3,
                        type => 'string',
                        title => 'E-mail Address',
                        format => 'email',
                        pattern => '^[^@]+@[^@]+$',
                    },
                    password => {
                        'x-order' => 4,
                        type => 'string',
                        format => 'password',
                    },
                    access => {
                        'x-order' => 5,
                        type => 'string',
                        enum => [qw( user moderator admin )],
                        default => 'user',
                    },
                    age => {
                        'x-order' => 6,
                        type => [qw( integer null )],
                        description => 'The person\'s age',
                    },
                    plugin => {
                        'x-order' => 7,
                        type => 'string',
                        default => 'password',
                    },
                    avatar => {
                        'x-order' => 8,
                        type => 'string',
                        format => 'filepath',
                        default => '',
                    },
                    created => {
                        'x-order' => 9,
                        type => 'string',
                        format => 'date-time',
                        default => 'now',
                    },
                },
            },
            'user schema read from database'
                or diag explain $app->yancy->schema( 'user' );
    };


    subtest 'single table from database' => sub {
        my $app = Yancy->new(
            config => {
                backend => $backend_url,
                schema => {
                    people => { read_schema => 1 },
                },
                editor => { require_user => undef, },
                read_schema => 0,
            },
        );

        is_deeply $app->yancy->schema( 'people' ),
            {
                type => 'object',
                required => [qw( name )],
                properties => {
                    id => {
                        'x-order' => 1,
                        readOnly => true,
                        type => 'integer',
                    },
                    name => {
                        'x-order' => 2,
                        type => 'string',
                    },
                    email => {
                        'x-order' => 3,
                        type => [ 'string', 'null' ],
                    },
                    age => {
                        type => [qw( integer null )],
                        'x-order' => 4,
                    },
                    contact => {
                        type => [qw( boolean null )],
                        default => 0,
                        'x-order' => 5,
                    },
                    phone => {
                        type => [qw( string null )],
                        'x-order' => 6,
                    },
                },
            },
            'people schema read from database'
                or diag explain $app->yancy->schema( 'people' );

        ok !$app->yancy->schema( 'user' ), 'user schema does not exist';
    };
};

subtest 'x-ignore' => sub {
    my $t = Test::Mojo->new( Yancy => {
        read_schema => 1,
        backend => $backend_url,
        editor => { require_user => undef, },
        schema => { people => { 'x-ignore' => 1 } },
    });
    $t->get_ok( '/yancy/api' )
      ->status_is( 200 )
      ->content_type_like( qr{^application/json} )
      ->json_has( '/definitions/user', 'user read from schema' )
      ->json_hasnt( '/definitions/people', 'people ignored from schema' )
      ;
};

subtest 'errors' => sub {

    subtest 'missing id field' => sub {
        my %missing_id = (
            backend => $backend_url,
            schema => {
                foo => {
                    type => 'object',
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
            editor => { require_user => undef, },
            read_schema => 0,
        );
        eval { Yancy->new( config => \%missing_id ) };
        ok $@, 'configuration dies';
        like $@, qr{ID field missing in properties for schema 'foo', field 'id'},
            'error is correct';

        my %missing_x_id = (
            backend => $backend_url,
            schema => {
                foo => {
                    type => 'object',
                    'x-id-field' => 'bar',
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
            editor => { require_user => undef, },
            read_schema => 0,
        );
        eval { Yancy->new( config => \%missing_x_id ) };
        ok $@, 'configuration dies';
        like $@, qr{ID field missing in properties for schema 'foo', field 'bar'},
            'error is correct';

        my %ignored_missing_id = (
            backend => $backend_url,
            schema => {
                foo => {
                    'x-ignore' => 1,
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
            editor => { require_user => undef, },
            read_schema => 0,
        );
        eval { Yancy->new( config => \%ignored_missing_id ) };
        ok !$@, 'configuration succeeds' or diag $@;
    };

    subtest 'no schema AND openapi' => sub {
        eval { Yancy->new( config => {
            openapi => {},
            backend => $backend_url,
            schema => {},
            editor => { require_user => undef, },
        } ) };
        ok $@, 'openapi AND schema should be fatal';
        like $@, qr{Cannot pass both openapi AND \(schema or read_schema\)};
    };

};

done_testing;
