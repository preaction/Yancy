
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
use Local::Test qw( init_backend load_fixtures );

my $schema = \%Yancy::Backend::Test::SCHEMA;
my %fixtures = load_fixtures( 'foreign-key-field' );
$schema->{ $_ } = $fixtures{ $_ } for keys %fixtures;
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

my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    schema => $schema,
    read_schema => 1,
    editor => { require_user => undef, },
} );

subtest 'register and run a filter' => sub {
    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };
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
    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-filter'} = [ [ 'test.with_params', 'hi' ] ];
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
    local $t->app->yancy->config->{schema}{user}{properties}{email}{'x-filter'} = [ [ 'yancy.wrap', 'hi' ] ];
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
    local $t->app->yancy->config->{schema}{user}{properties}{email}{'x-filter'} = [
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
    local $t->app->yancy->config->{schema}{user}{properties}{email}{'x-filter'} = [ [ 'yancy.wrap', 'hi' ] ];
    my $user = {
        username => 'unfiltered',
        email => 'filter@example.com',
        password => 'unfiltered',
    };
    my $filtered_user = $t->app->yancy->filter->apply( user => $user );
    is_deeply $filtered_user->{email}, { hi => $user->{email} }, 'filter did not mutate input' or diag explain $filtered_user;
};

subtest 'run from_helper filter' => sub {
    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-filter'} = [ [ 'yancy.from_helper', 'yancy.hello' ] ];
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
    local $t->app->yancy->config->{schema}{people}{'x-filter'} = [ 'test.lc_email' ];

    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'doug@preaction.me',
        'filter on object is run';
};

subtest 'run overlay_from_helper filter' => sub {
    local $t->app->yancy->config->{schema}{people}{'x-filter'}[0] = [ 'yancy.overlay_from_helper' => 'email', 'yancy.hello' ];
    my $person = {
        name => 'Doug',
        email => 'dOuG@pReAcTiOn.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, 'Hi there!',
        'filter on object is run';
};

subtest 'register filters from config' => sub {
    my $t = Test::Mojo->new( 'Yancy', {
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

    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-filter'} = [ 'test.digest' ];
    local $t->app->yancy->config->{schema}{user}{properties}{password}{'x-digest'} = { type => 'SHA-1' };

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
    local $t->app->yancy->config->{schema}{people}{properties}{email}{'x-filter'}[0] = [ 'yancy.mask' => '[^@]{2,}(?=[^@]{2,4}@)', '*' ];
    my $person = {
        name => 'Doug',
        email => 'doug@preaction.me',
    };
    my $filtered_person = $t->app->yancy->filter->apply( people => $person );
    is $filtered_person->{email}, '**ug@preaction.me',
        'filter on object is run';
};

subtest 'run get_related filter' => sub {
    local $t->app->yancy->config->{schema}{addresses}{'x-filter'}[0] = [
        'yancy.get_related' => address_type => 'address_type_id',
    ];
    my $address_type_id = $t->app->yancy->create( address_types => { address_type => 'Foo' } );
    my $address = {
        street => '123 Example St.',
        address_type_id => $address_type_id,
    };
    my $filtered_address = $t->app->yancy->filter->apply( addresses => $address );
    is $filtered_address->{address_type}{address_type}, 'Foo',
        'get_related filter adds related data';
    ok !$address->{address_type}, 'original is not modified';
};

subtest 'run list_related filter' => sub {
    local $t->app->yancy->config->{schema}{address_types}{'x-filter'}[0] = [
        'yancy.list_related' => addresses => [ address_type_id => addresses => 'address_type_id' ],
    ];
    my $address_type = { address_type => 'Bar' };
    my $address_type_id = $t->app->yancy->create( address_types => $address_type );
    $address_type->{ address_type_id } = $address_type_id;
    my @address_ids = (
        $t->app->yancy->create(
            addresses => {
                address_type_id => $address_type_id,
                street => '231 Example St.',
            },
        ),
        $t->app->yancy->create(
            addresses => {
                address_type_id => $address_type_id,
                street => '312 Example St.',
            },
        ),
    );
    my $filtered_address_type = $t->app->yancy->filter->apply( address_types => $address_type );
    is $filtered_address_type->{addresses}[0]{street}, '231 Example St.',
        'list_related filter adds related data';
    ok !$address_type->{addresses}, 'original is not modified';
};

subtest 'run set_related filter' => sub {
    my $address_type = { address_type => 'Fizz' };
    my $address_type_id = $t->app->yancy->create( address_types => $address_type );
    $address_type->{ address_type_id } = $address_type_id;

    subtest 'single item, set' => sub {
        local $t->app->yancy->config->{schema}{addresses}{'x-filter'}[0] = [
            'yancy.set_related' => address_type => [ address_types => 'address_type_id' ],
        ];
        my $address = {
            address_type => {
                address_type_id => $address_type_id,
                address_type => 'Fuzz',
            },
        };
        my $filtered_address = $t->app->yancy->filter->apply( addresses => $address );
        ok $address->{address_type}, 'original item is not modified';
        ok !$filtered_address->{address_type}, 'related field is removed';
        is $t->app->yancy->get( address_types => $address_type_id )->{address_type}, 'Fuzz',
            'related item is updated';
    };

    subtest 'single item, create' => sub {
        local $t->app->yancy->config->{schema}{addresses}{'x-filter'}[0] = [
            'yancy.set_related' => address_type => [ address_types => 'address_type_id' ],
        ];
        my $address = {
            address_type => { address_type => 'Buzz' },
        };
        my $filtered_address = $t->app->yancy->filter->apply( addresses => $address );
        ok $address->{address_type}, 'original item is not modified';
        ok !$filtered_address->{address_type}, 'related field is removed';
        ok $filtered_address->{address_type_id}, 'id is added to item';
        ok my $new_type = $t->app->yancy->get( address_types=> $filtered_address->{address_type_id} ),
            'new address type exists';
        is $new_type->{address_type}, 'Buzz', 'address_type is correct';
    };

    # Multiple, set
    subtest 'multiple items, set' => sub {
        local $t->app->yancy->config->{schema}{address_types}{'x-filter'}[0] = [
            'yancy.set_related' => addresses => 'addresses',
        ];
        my $address_type = { address_type => 'Station' };
        my $address_type_id = $t->app->yancy->create( address_types => $address_type );
        $address_type->{ address_type_id } = $address_type_id;
        my @addresses = (
            {
                address_type_id => $address_type_id,
                street => 'Rigel 4',
            },
            {
                address_type_id => $address_type_id,
                street => 'Deep Space 9',
            },
        );
        $_->{address_id} = $t->app->yancy->create( addresses => $_ ) for @addresses;
        $address_type->{ addresses } = [
            {
                %{ $addresses[0] },
                street => 'Rigel 5',
            },
            {
                %{ $addresses[1] },
                street => 'Deep Space 6',
            }
        ];
        my $filtered_address_type = $t->app->yancy->filter->apply(
            address_types => $address_type,
        );
        ok !$filtered_address_type->{addresses}, 'related items are removed by filter';
        is $t->app->yancy->get( addresses => $addresses[0]->{address_id} )->{street},
            'Rigel 5', 'address 0 is updated';
        is $t->app->yancy->get( addresses => $addresses[1]->{address_id} )->{street},
            'Deep Space 6', 'address 1 is updated';
    };

    # Multiple, create
    subtest 'multiple items, create' => sub {
        local $t->app->yancy->config->{schema}{address_types}{'x-filter'}[0] = [
            'yancy.set_related' => addresses => 'addresses',
        ];
        my $address_type = { address_type => 'Starport' };
        my $address_type_id = $t->app->yancy->create( address_types => $address_type );
        $address_type->{ address_type_id } = $address_type_id;
        my @addresses = (
            {
                address_type_id => $address_type_id,
                street => 'Tatooine',
            },
            {
                address_type_id => $address_type_id,
                street => 'Naboo',
            },
        );
        $address_type->{ addresses } = \@addresses;
        my $filtered_address_type = $t->app->yancy->filter->apply(
            address_types => $address_type,
        );
        ok !$filtered_address_type->{addresses}, 'related items are removed by filter';
        my @list = (
            $t->app->yancy->list( addresses => { street => 'Tatooine' } ),
            $t->app->yancy->list( addresses => { street => 'Naboo' } ),
        );
        is scalar @list, 2, 'both new addresses found';
    };


};

done_testing;
