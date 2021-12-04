
=head1 DESCRIPTION

This test makes sure that filters can be registered and are executed
appropriately.

=head1 SEE ALSO

L<Yancy::Backend::Memory>

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

my $schema = \%Local::Test::SCHEMA;
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
my ( $backend_url, $backend, %items ) = init_backend( $schema, %data );

my $t = Test::Mojo->new( 'Mojolicious' );
$t->app->plugin( Yancy => {
    backend => $backend_url,
    schema => $schema,
    read_schema => 1,
    editor => { require_user => undef, },
} );

subtest 'register and run a filter' => sub {
    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };
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
    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-filter'} = [ [ 'test.with_params', 'hi' ] ];
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

subtest 'run wrap filter' => sub {
    local $t->app->yancy->backend->schema->{user}{properties}{email}{'x-filter'} = [ [ 'yancy.wrap', 'hi' ] ];
    my $email = 'filter@example.com';
    my $user = {
        username => 'unfiltered',
        email => $email,
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is_deeply $filtered_user->{email}, { hi => $email }, 'filter applied' or diag explain $filtered_user;
    is $filtered_user->{password}, 'unfiltered', 'no filter, no change';
};

subtest 'run unwrap filter' => sub {
    local $t->app->yancy->backend->schema->{user}{properties}{email}{'x-filter'} = [
        [ 'yancy.wrap', qw(hi there) ],
        [ 'yancy.unwrap', qw(there hi) ],
    ];
    my $email = 'filter@example.com';
    my $user = {
        username => 'unfiltered',
        email => $email,
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is_deeply $filtered_user->{email}, $email, 'filter applied, identity' or diag explain $filtered_user;
};

subtest 'filter no mutate input' => sub {
    local $t->app->yancy->backend->schema->{user}{properties}{email}{'x-filter'} = [ [ 'yancy.wrap', 'hi' ] ];
    my $user = {
        username => 'unfiltered',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is_deeply $filtered_user->{email}, { hi => $user->{email} }, 'filter did not mutate input' or diag explain $filtered_user;
};

subtest 'run from_helper filter' => sub {
    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-filter'} = [ [ 'yancy.from_helper', 'yancy.hello' ] ];
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
    local $t->app->yancy->backend->schema->{people}{'x-filter'} = [ 'test.lc_email' ];

    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'doug@preaction.me',
        'filter on object is run';
};

subtest 'run overlay_from_helper filter' => sub {
    local $t->app->yancy->backend->schema->{people}{'x-filter'}[0] = [ 'yancy.overlay_from_helper' => 'email', 'yancy.hello' ];
    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'Hi there!',
        'filter on object is run';
};

subtest 'register filters from config' => sub {
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( Yancy => {
        backend => $backend_url,
        schema => $schema,
        read_schema => 1,
        editor => { require_user => undef, },
        filters => {
            'test.digest' => sub {
                my ( $name, $value, $conf ) = @_;
                my $digest = $conf->{'x-digest'};
                Digest->new( $digest->{type} )->add( $value )->b64digest;
            },
        },
    } );

    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->backend->schema->{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };

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

subtest 'run mask filter' => sub {
    local $t->app->yancy->backend->schema->{people}{properties}{email}{'x-filter'}[0] = [ 'yancy.mask' => '[^@]{2,}(?=[^@]{2,4}@)', '*' ];
    my $person = {
        name => 'Doug',
        email => 'doug@preaction.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, '**ug@preaction.me',
        'filter on object is run';
};

subtest 'filter not found error' => sub {
    $t->app->log->history([]);
    local $t->app->yancy->backend->schema->{user}{properties}{email}{'x-filter'}[0] = [ 'DOES.NOT.EXIST' ];
    my $user = {
        username => 'filter',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    eval { $t->app->yancy->filter->apply( user => $user ) };
    ok my $err = $@, 'error is thrown';
    like $err, qr{Unknown filter: DOES\.NOT\.EXIST};
    ok my $log = shift @{ $t->app->log->history }, 'log exists';
    is $log->[1], 'fatal', 'log level is fatal';
    like $log->[3], qr{Unknown filter: DOES\.NOT\.EXIST}, 'log message is correct';
};

done_testing;
