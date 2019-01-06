
=head1 DESCRIPTION

This test makes sure that filters can be registered and are executed
appropriately.

=head1 SEE ALSO

L<Yancy::Backend::Test>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use Digest;
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my $collections = {
    people => {
        required => [qw( name )],
        properties => {
            id => {
                'x-order' => 1,
            },
            name => {
                'x-order' => 2,
                description => 'The real name of the person',
            },
            email => {
                'x-order' => 3,
                pattern => '^[^@]+@[^@]+$',
            },
        },
    },
    user => {
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        required => [qw( username email password )],
        properties => {
            username => {
                type => 'string',
                'x-order' => 1,
            },
            email => {
                type => 'string',
                'x-order' => 2,
            },
            password => {
                type => 'string',
                format => 'password',
                'x-order' => 3,
            },
            access => {
                type => 'string',
                enum => [qw( user moderator admin )],
                'x-order' => 4,
            },
        },
    },
};
my %data = (
    people => [
        {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
        {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
        },
    ],
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => 'ignore',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => 'ignore',
        },
    ],
);
my ( $backend_url, $backend, %items ) = init_backend( $collections, %data );

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );

subtest 'register and run a filter' => sub {
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };
    $t->app->yancy->filter->add(
        'test.digest' => sub {
            my ( $name, $value, $conf ) = @_;
            my $digest = $conf->{'x-digest'};
            Digest->new( $digest->{type} )->add( $value )->b64digest;
        },
    );

    my $user = {
        username => 'filter',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is $filtered_user->{email}, $user->{email}, 'no filter, no change';
    is $filtered_user->{password},
        Digest->new( 'SHA-1' )->add( 'unfiltered' )->b64digest,
        'filter is executed';
};

subtest 'register and run parameterised filter' => sub {
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ [ 'test.with_params', 'hi' ] ];
    $t->app->yancy->filter->add(
        'test.with_params' => sub {
            my ( $name, $value, $conf, @params ) = @_;
            $value . $params[0];
        },
    );
    my $user = {
        username => 'filter',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is $filtered_user->{email}, $user->{email}, 'no filter, no change';
    is $filtered_user->{password}, 'unfilteredhi', 'filter params used';
};

subtest 'run from_helper filter' => sub {
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ [ 'yancy.from_helper', 'yancy.hello' ] ];
    $t->app->helper( 'yancy.hello' => sub { 'Hi there!' } );
    my $user = {
        username => 'filter',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is $filtered_user->{email}, $user->{email}, 'no filter, no change';
    is $filtered_user->{password}, 'Hi there!', 'filter<-helper';
};

subtest 'filter works recursively' => sub {
    $t->app->yancy->filter->add(
        'test.lc_email' => sub {
            my ( $name, $value, $conf ) = @_;
            $value->{ email } = lc $value->{ email };
            return $value;
        },
    );
    local $t->app->yancy->config->{collections}{people}{'x-filter'} = [ 'test.lc_email' ];

    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'doug@preaction.me',
        'filter on object is run';
};

subtest 'run overlay_from_helper filter' => sub {
    local $t->app->yancy->config->{collections}{people}{'x-filter'}[0] = [ 'yancy.overlay_from_helper' => 'email', 'yancy.hello' ];
    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'Hi there!',
        'filter on object is run';
};

subtest 'api runs filters during set' => sub {
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };
    my $doug = {
        %{ $backend->get( user => 'doug' ) },
        password => 'qwe123',
    };
    $t->put_ok( '/yancy/api/user/doug', json => $doug )
      ->status_is( 200 );
    is $backend->get( user => 'doug' )->{password},
        Digest->new( 'SHA-1' )->add( 'qwe123' )->b64digest,
        'new password is digested correctly'
};

subtest 'api runs filters during create' => sub {
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };
    my $new_user = {
        username => 'qubert',
        email => 'qubert@example.com',
        password => 'stalemate',
    };
    $t->post_ok( '/yancy/api/user', json => $new_user )
      ->status_is( 201 );
    is $backend->get( user => 'qubert' )->{password},
        Digest->new( 'SHA-1' )->add( 'stalemate' )->b64digest,
        'new password is digested correctly'
};

subtest 'register filters from config' => sub {
    my $t = Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        collections => $collections,
        read_schema => 1,
        filters => {
            'test.digest' => sub {
                my ( $name, $value, $conf ) = @_;
                my $digest = $conf->{'x-digest'};
                Digest->new( $digest->{type} )->add( $value )->b64digest;
            },
        },
    } );

    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{collections}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };

    my $user = {
        username => 'filter',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is $filtered_user->{email}, $user->{email}, 'no filter, no change';
    is $filtered_user->{password},
        Digest->new( 'SHA-1' )->add( 'unfiltered' )->b64digest,
        'filter is executed';
};

done_testing;
