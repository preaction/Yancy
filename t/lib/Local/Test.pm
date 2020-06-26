package Local::Test;

=head1 SYNOPSIS

    use Test::More;
    use Local::Test qw( test_backend init_backend );

    subtest 'test my backend' => \&test_backend, $backend_object,
        schema => { ... },
        $list_objects,
        $set_object,
        $create_object;

=head1 DESCRIPTION

This module contains helper routines for testing Yancy.

=head1 SEE ALSO

L<Test::Builder>

=cut

use Mojo::Base '-strict';
use Exporter 'import';
use Test::Builder;
use Test::More ();
use Yancy::Util qw( load_backend );
use Yancy::Backend::Test;
use JSON::Validator;
use Mojo::JSON qw( decode_json true false );
use Mojo::File qw( curfile );

our @EXPORT_OK = qw( test_backend init_backend backend_common load_fixtures );

=sub init_backend

    my ( $url, $backend, %out_items ) = init_backend( $schema, %items );

Initialize a backend for testing with the given items. This routine will
check the C<TEST_YANCY_BACKEND> environment variable for connection
details, if any. Otherwise, it will create a L<Yancy::Backend::Test>
object for mock testing.

B<NOTE>: This routine will delete all existing data in the given
schema!

=cut

my @ordered_schemas;
my %to_delete;
my $backend;
sub init_backend {
    my ( $schema, %items ) = @_;
    my %out_items;
    my $backend_url = $ENV{TEST_YANCY_BACKEND} || 'test://localhost';
    $backend = load_backend( $backend_url, $schema );
    my @concrete_schemas = grep !$schema->{ $_ }{'x-view'}, keys %$schema;

    # Try to put tables with foreign keys before the tables they
    # reference so we don't get key failures when we create / delete
    my %references;
    for my $schema_name ( @concrete_schemas ) {
        for my $prop_name ( keys %{ $schema->{ $schema_name }{ properties } } ) {
            my $prop = $schema->{ $schema_name }{ properties }{ $prop_name };
            if ( my $ref_to = $prop->{ 'x-foreign-key' } ) {
                $references{ $schema_name }{ $ref_to }++;
            }
        }
    }
    # Get a table. See if it references anything. If so, try to add that
    # table first (if it's not already)
    my $check_refs; $check_refs = sub {
        my ( $table ) = @_;
        my @refs = keys %{ $references{ $table } || {} };
        # If this table is already in the order, we don't have to add it
        # again...
        return if grep { $_ eq $table } @ordered_schemas;
        my %satisfied = map { $_ => 1 } @ordered_schemas;
        # If it references nothing, or if all the references are
        # satisfied, we can add this one.
        if ( !@refs || grep { $satisfied{ $_ } } @refs == @refs ) {
            push @ordered_schemas, $table,
                grep { $schema->{ $_ }{ 'x-view' } && $schema->{ $_ }{ 'x-view' } eq $table } keys %$schema;
            return;
        }
        for my $ref_table ( @refs ) {
            $check_refs->( $ref_table );
        }
        push @ordered_schemas, $table,
            grep { $schema->{ $_ }{ 'x-view' } && $schema->{ $_ }{ 'x-view' } eq $table } keys %$schema;
    };
    for my $table ( @concrete_schemas ) {
        $check_refs->( $table );
    }

    for my $schema_name ( reverse @ordered_schemas ) {
        next unless $schema->{ $schema_name };
        my $id_field = $schema->{ $schema_name }{ 'x-id-field' } // 'id';
        for my $item ( @{ $backend->list( $schema_name )->{items} } ) {
            $backend->delete( $schema_name, $item->{ $id_field } );
        }
    }

    for my $schema_name ( @ordered_schemas ) {
        next unless $items{ $schema_name };
        my $id_field = $schema->{ $schema_name }{ 'x-id-field' } // 'id';
        for my $item ( @{ $items{ $schema_name } } ) {
            my $id = $backend->create( $schema_name, $item );
            my $new_item = $backend->get( $schema_name, $id );
            push @{ $out_items{ $schema_name } }, $new_item;
            push @{ $to_delete{ $schema_name } }, $id;
        }
    }
    return ( $backend_url, $backend, %out_items );
}

END {
    for my $schema ( reverse @ordered_schemas ) {
        eval { $backend->delete( $schema, $_ ) } for @{ $to_delete{ $schema } };
    }
};

# This is used by all the tests as the "one source of the truth", since
# they all end up talking to either the mock or a real backend.
# It therefore needs to end up matching what read_schema will give -
# anything read_schema can't produce needs to also go in SCHEMA_MICRO below
%Yancy::Backend::Test::SCHEMA = (
    blog => {
        type => 'object',
        required => [qw( title markdown )],
        properties => {
            id => {
              'x-order' => 1,
              readOnly => true,
              type => 'integer',
            },
            username => {
              'x-order' => 2,
              type => [ 'string', 'null' ],
              'x-foreign-key' => 'user',
            },
            title => {
              'x-order' => 3,
              type => 'string',
            },
            slug => {
              'x-order' => 4,
              type => [ 'string', 'null' ],
            },
            markdown => {
              'x-order' => 5,
              type => 'string',
            },
            html => {
              type => [ 'string', 'null' ],
              'x-order' => 6,
            },
            is_published => {
              type => 'boolean',
              'x-order' => 7,
              default => 0,
            },
            published_date => {
                type => [ 'string', 'null' ],
                format => 'date-time',
                'x-order' => 8,
                default => 'now',
            },
        },
    },
    mojo_migrations => {
        type => 'object',
        required => [qw( name version )],
        'x-id-field' => 'name',
        'x-ignore' => 1,
        properties => {
            name => {
                'x-order' => 1,
                type => 'string',
            },
            version => {
                'x-order' => 2,
                type => 'integer',
            },
        },
    },
    people => {
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
                'x-order' => 4,
                type => [qw( integer null )],
            },
            contact => {
                'x-order' => 5,
                default => 0,
                type => [qw( boolean null )],
            },
            phone => {
                'x-order' => 6,
                type => [qw( string null )],
            },
        },
    },
    user => {
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
                type => 'string',
                format => 'date-time',
                'x-order' => 9,
                default => 'now',
            },
        },
    },
    usermini => {
        type => 'object',
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        'x-view' => { schema => 'user' },
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
        },
    },
    userviewnoprops => {
        type => 'object',
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        'x-view' => { schema => 'user' },
    },
);
%Yancy::Backend::Test::SCHEMA_MICRO = (
    user => {
        'x-list-columns' => [qw( username email )],
        properties => {
            email => {
                title => 'E-mail Address',
                format => 'email',
                pattern => '^[^@]+@[^@]+$',
            },
            password => {
                format => 'password',
            },
            age => {
                description => 'The person\'s age',
            },
            avatar => {
                format => 'filepath',
            },
        },
    },
    usermini => {
        type => 'object',
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        'x-view' => { schema => 'user' },
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
        },
    },
    userviewnoprops => {
        type => 'object',
        'x-id-field' => 'username',
        'x-list-columns' => [qw( username email )],
        'x-view' => { schema => 'user' },
    },
);
@Yancy::Backend::Test::SCHEMA_ADDED_COLLS = qw(
    usermini
    userviewnoprops
);

=sub test_backend

    my $result = test_backend(
        $backend, $schema_name, $schema,
        $list, $create, $set_to,
    );

Test that a backend works properly. C<$backend> is a backend object.
C<$schema_name> is the schema name to test. C<$schema> is the JSON
schema. C<$list> is a list of objects already in the backend. C<$create>
is a new object to test creating an object. C<$set_to> is values the
newly-create object will be set to, before being deleted.

=cut

sub test_backend {
    my (
        $be, $coll_name, $coll_conf,
        $list_key, $list,
        $list_type, # 'string' or 'integer' or 'boolean'
        $create, $create_overlay,
        $set_to,
        $filter,
    ) = @_;
    my $id_field = $coll_conf->{ 'x-id-field' } || 'id';
    my $tb = Test::Builder->new();
    $filter //= sub { };

    # The list of tests to run, an array of hashrefs. Backend tests may
    # change the data recorded in the backend, so they must be run in
    # order. Each test has the following keys:
    #
    #   name        - The name of the test
    #   method      - The method being tested
    #   args        - The args to the method. May be an arrayref or
    #                 a sub that return a list when called
    #
    # And one of:
    #
    #   expect      - The expected return value tested with is_deeply
    #   test        - A subref to test the result of the method (given
    #                 as arguments to the subref)
    #
    # Each test can assume that the previous tests have all been run,
    # but maybe not successfully.
    my @tests = (
        {
            name => 'list all items is correct',
            method => 'list',
            args => [ $coll_name ],
            expect => { items => $list, total => scalar @$list },
        },

        {
            name => 'list with offset is correct',
            method => 'list',
            args => [ $coll_name, {}, { offset => 1 } ],
            expect => { items => [ @{ $list }[1..$#$list] ], total => scalar @$list },
        },

        {
            name => 'list with limit is correct',
            method => 'list',
            args => [ $coll_name, {}, { limit => 1 } ],
            expect => { items => [ $list->[0] ], total => scalar @$list },
        },

        {
            name => 'list with offset/limit is correct',
            method => 'list',
            args => [ $coll_name, {}, { offset => 1, limit => 1 } ],
            expect => { items => [ $list->[1] ], total => scalar @$list },
        },

        $list_type eq 'boolean' ? (
        {
            name => 'list with search boolean true is correct',
            method => 'list',
            do {
                my @expect_list = grep $_->{ $list_key }, @{ $list };
                (
                    args => [ $coll_name, { -bool => $list_key } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },
        ) : (
        {
            name => 'list with search equals is correct',
            method => 'list',
            do {
                my $value = $list->[0]{ $list_key };
                my @expect_list = grep { $_->{ $list_key } eq $value } @{ $list };
                (
                    args => [ $coll_name, { $list_key => $value } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },
        ),

        $list_type eq 'string' ? (
        {
            name => 'list with search starts with is correct',
            method => 'list',
            do {
                my $value = substr $list->[0]{ $list_key }, 0, 4;
                my @expect_list = grep { $_->{ $list_key } =~ /^$value/ } @{ $list };
                $value .= '%';
                (
                    args => [ $coll_name, { $list_key => { like => $value } } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },

        {
            name => 'list with search ends with is correct',
            method => 'list',
            do {
                my $value = substr $list->[0]{ $list_key }, -4;
                my @expect_list = grep { $_->{ $list_key } =~ /$value$/ } @{ $list };
                $value = '%' . $value;
                (
                    args => [ $coll_name, { $list_key => { like => $value } } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },

        {
            name => 'list with order by just name (not hash) is correct',
            method => 'list',
            do {
                my @expect_list = sort { $a->{ $list_key } cmp $b->{ $list_key } } @{ $list };
                (
                    args => [ $coll_name, {}, { order_by => $list_key } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },

        {
            name => 'list with order by array of name is correct',
            method => 'list',
            do {
                my @expect_list = sort { $a->{ $list_key } cmp $b->{ $list_key } } @{ $list };
                (
                    args => [ $coll_name, {}, { order_by => [ $list_key ] } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },

        {
            name => 'list with order by asc is correct',
            method => 'list',
            do {
                my @expect_list = sort { $a->{ $list_key } cmp $b->{ $list_key } } @{ $list };
                (
                    args => [ $coll_name, {}, { order_by => { -asc => $list_key } } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },

        {
            name => 'list with order by name is correct',
            method => 'list',
            do {
                my @expect_list = sort { $b->{ $list_key } cmp $a->{ $list_key } } @{ $list };
                (
                    args => [ $coll_name, {}, { order_by => { -desc => $list_key } } ],
                    expect => { items => \@expect_list, total => scalar @expect_list },
                );
            },
        },
        ) : (),

        {
            name => 'get item by id',
            method => 'get',
            args => [ $coll_name => $list->[0]{ $id_field } ],
            expect => $list->[0],
        },

        {
            name => 'create',
            method => 'create',
            args => [ $coll_name => $create ],
            test => sub {
                my ( $got_id ) = @_;
                Test::More::ok( $got_id, 'create() returns ID' );
                $create = { %$create, $id_field => $got_id, %$create_overlay };
                $be->get_p( $coll_name, $got_id )->then( sub {
                    my ( $got ) = @_;
                    my %got_maybe_noid = %$got;
                    $filter->( \%got_maybe_noid );
                    delete $got_maybe_noid{id} if $id_field ne 'id';
                    Test::More::is_deeply( \%got_maybe_noid, $create, 'created item correct' )
                        or $tb->diag( $tb->explain( [ \%got_maybe_noid, $got ] ) );
                } )->wait;
            },
        },

        {
            name => 'set (success)',
            method => 'set',
            args => sub { $coll_name => $create->{ $id_field } => $set_to },
            test => sub {
                my ( $ok ) = @_;
                Test::More::ok( $ok, 'set() returns boolean true if row modified' );
                $be->get_p( $coll_name, $create->{ $id_field } )->then( sub {
                    my ( $got ) = @_;
                    my %got_maybe_noid = %$got;
                    $filter->( \%got_maybe_noid );
                    delete $got_maybe_noid{id} if $id_field ne 'id';
                    Test::More::is_deeply( \%got_maybe_noid, { %$create, %$set_to }, 'set item correct' )
                        or $tb->diag( $tb->explain( [ \%got_maybe_noid, $got ] ) );
                } )->wait;
            },
        },

        ({
            # Test causes PG to segfault on Travis, I suspect because of
            # a bug in DBD::Pg's handling of pg_error_field
            name => 'set (failure)',
            method => 'set',
            args => [ $coll_name => 'DOES_NOT_EXIST' => $set_to ],
            test => sub {
                my ( $not_ok ) = @_;
                Test::More::ok( !$not_ok, 'set() returns boolean false if row not modified' );
            },
        })x!$ENV{TEST_ONLINE_PG},

        {
            name => 'delete (success)',
            method => 'delete',
            args => sub { $coll_name => $create->{ $id_field } },
            test => sub {
                my ( $ok ) = @_;
                Test::More::ok( $ok, 'delete() returns boolean true if row deleted' );
                $tb->ok( !$be->get( $coll_name, $create->{ $id_field } ),
                    'deleted item not found',
                );
            },
        },

        {
            name => 'delete (failure)',
            method => 'delete',
            args => sub { $coll_name => $create->{ $id_field } },
            test => sub {
                my ( $not_ok ) = @_;
                Test::More::ok( !$not_ok, 'delete() returns boolean false if row not deleted' );
            },
        },

    );

    my $run_tests = sub {
        my ( $run ) = @_;
        for my $test ( @tests ) {
            my $method = $test->{method};
            my $name = $test->{name};
            my @args = ref $test->{args} eq 'CODE' ? $test->{args}->() : @{ $test->{args} };
            my $cb = $test->{test} || sub {
                my ( $got ) = @_;
                if ( ref $got->{items} eq 'ARRAY' ) {
                    $filter->( $_ ) for @{ $got->{items} };
                }
                else {
                    $filter->( $got );
                }
                Test::More::is_deeply( $got, $test->{expect}, $name )
                    or $tb->diag( $tb->explain( $got ) );
            };
            $run->( $cb, $method, $name, @args );
        }
    };

    $run_tests->( sub {
        my ( $cb, $method, $name, @args ) = @_;
        $tb->subtest( $name => sub {
            my @got = $be->$method( @args );
            $cb->( @got );
        } );
    } );

    $run_tests->( sub {
        my ( $cb, $method, $name, @args ) = @_;
        $tb->subtest( $name . ' (async, promises)' => sub {
            my $async_method = $method . "_p";
            my $promise = $be->$async_method( @args );
            $promise->then(
                $cb,
                sub {
                    Test::More::fail(
                        'Promise rejected: ' . join '', Test::More::explain( \@_ )
                    )
                },
            );
            $promise->wait;
        } );
    } );

    $tb->subtest( read_schema => sub {
        my $got_schema = $be->read_schema;
        my $expect_schema = {
            people => {
                type => 'object',
                required => [qw( name )],
                properties => {
                    id => { type => 'integer', 'x-order' => 1, readOnly => true },
                    name => { type => 'string', 'x-order' => 2 },
                    email => { type => [ 'string', 'null' ], 'x-order' => 3 },
                    age => { type => [ 'integer', 'null' ], 'x-order' => 4 },
                    contact => { type => [ 'boolean', 'null' ], default => 0, 'x-order' => 5 },
                    phone => { type => [ 'string', 'null' ], 'x-order' => 6 },
                },
            },
            user => {
                type => 'object',
                'x-id-field' => 'username',
                required => [qw( username email password )],
                properties => {
                    id => { type => 'integer', 'x-order' => 1, readOnly => true },
                    username => { type => 'string', 'x-order' => 2 },
                    email => { type => 'string', 'x-order' => 3 },
                    password => { type => 'string', 'x-order' => 4 },
                    access => {
                        type => 'string',
                        enum => [qw( user moderator admin )],
                        'x-order' => 5,
                        default => 'user',
                    },
                    age => {
                        type => [ 'integer', 'null' ],
                        'x-order' => 6,
                    },
                    plugin => {
                        type => 'string',
                        default => 'password',
                        'x-order' => 7,
                    },
                    avatar => {
                        type => 'string',
                        'x-order' => 8,
                        default => '',
                    },
                    created => {
                        type => 'string',
                        format => 'date-time',
                        'x-order' => 9,
                        default => 'now',
                    },
                },
            },
            blog => {
                type => 'object',
                required => [qw( title markdown )],
                properties => {
                    id => { type => 'integer', 'x-order' => 1, readOnly => true },
                    username => { type => [ 'string', 'null' ], 'x-order' => 2, 'x-foreign-key' => 'user' },
                    title => { type => 'string', 'x-order' => 3 },
                    slug => { type => [ 'string', 'null' ], 'x-order' => 4 },
                    markdown => { type => 'string', 'x-order' => 5 },
                    html => { type => [ 'string', 'null' ], 'x-order' => 6 },
                    is_published => { type => 'boolean', 'x-order' => 7, default => 0 },
                    published_date => { type => [ 'string', 'null' ], format => 'date-time', 'x-order' => 8, default => 'now' },
                },
            },
            mojo_migrations => {
                type => 'object',
                'x-ignore' => 1,
                required => [qw( name version )],
                'x-id-field' => 'name',
                properties => {
                    name => { type => 'string', 'x-order' => 1 },
                    version => { type => 'integer', 'x-order' => 2 },
                },
            },
        };

        Test::More::is_deeply(
            $got_schema, $expect_schema, 'schema read from database is correct',
        ) or $tb->diag( $tb->explain( $got_schema ) );

        $tb->subtest( 'single schema read from database validates with JSON::Validator' => sub {
            my $v = JSON::Validator->new(
                coerce => { booleans => 1, numbers => 1 },
            );
            $v->formats->{ markdown } = sub { 1 };
            $v->formats->{ tel } = sub { 1 };
            my $got_table = $be->read_schema( $coll_name );
            eval { $v->schema( $got_table ) };
            Test::More::is( $@, '', 'schema valid' )
                or $tb->diag( $tb->explain( $got_table ) );
            my $got = $be->get( $coll_name => $list->[0]{ $id_field } );
            my @errors = $v->validate( $got );
            $tb->ok( !@errors, 'no validation errors' )
                or $tb->diag( $tb->explain( \@errors ) );
        } );

    });

}

=sub backend_common

    backend_common( $backend, \&insert_item, $schema );

Runs various tests on the given L<Yancy::Backend> instance. The code is
a backend-specific procedure to create items, probably a closure.

=cut

sub backend_common {
    my ( $backend, $insert_item, $schema ) = @_;
    my $tb = Test::Builder->new();
    my %person_one = $insert_item->( people =>
        name => 'person One',
        email => 'one@example.com',
        age => undef, contact => 1, phone => undef,
    );
    my %person_two = $insert_item->( people =>
        name => 'person Two',
        email => 'two@example.com',
        age => undef, contact => 0, phone => undef,
    );
    my %person_three = (
        name => 'person Three',
        email => 'three@example.com',
        age => undef, contact => undef, phone => undef,
    );
    Test::More::subtest( 'default id field' => \&test_backend, $backend,
        people => $schema->{ people }, # schema
        'name', # list key
        [ \%person_one, \%person_two ], # List (already in backend)
        'string',
        \%person_three, # Create/Delete test
        {}, # create overlay
        { name => 'Set' }, # Set test
        );
    Test::More::subtest( 'boolean list' => \&test_backend, $backend,
        people => $schema->{ people }, # schema
        'contact', # list key
        [ \%person_one, \%person_two ], # List (already in backend)
        'boolean',
        \%person_three, # Create/Delete test
        {}, # create overlay
        { name => 'Set' }, # Set test
        );
    my %user_one = $insert_item->( 'user',
        username => 'one',
        email => 'one@example.com',
        access => 'user',
        password => 'p1',
        age => 7,
        plugin => 'password',
        avatar => '',
    );
    my %user_two = $insert_item->( 'user',
        username => 'two',
        email => 'two@example.com',
        access => 'moderator',
        password => 'p2',
        age => 7,
        plugin => 'password',
        avatar => '',
    );
    my %user_three = (
        username => 'three',
        email => 'three@example.com',
        access => 'admin',
        password => 'p3',
        age => undef,
        plugin => 'password',
        avatar => '',
    );
    Test::More::subtest( 'custom id field' => \&test_backend, $backend,
        user => $schema->{ user }, # schema
        'username', # list key
        [ \%user_one, \%user_two ], # List (already in backend)
        'string',
        \%user_three, # Create/Delete test
        {}, # create overlay
        { email => 'test@example.com' }, # Set test
        # Filter: Test that created is created correctly, then remove it
        # so the tests pass
        sub {
            my ( $user ) = @_;
            Test::More::like $user->{created}, qr{\d{4}-\d{2}-\d{2}};
            delete $user->{created};
        },
        );
    Test::More::subtest( 'number list' => \&test_backend, $backend,
        user => $schema->{ user }, # schema
        'age', # list key
        [ \%user_one, \%user_two ], # List (already in backend)
        'integer',
        \%user_three, # Create/Delete test
        {}, # create overlay
        { email => 'test@example.com' }, # Set test
        # Filter: Test that created is created correctly, then remove it
        # so the tests pass
        sub {
            my ( $user ) = @_;
            Test::More::like $user->{created}, qr{\d{4}-\d{2}-\d{2}};
            delete $user->{created};
        },
        );
    my $got = $backend->get( 'usermini', 'one' );
    Test::More::is_deeply(
        $got,
        { 'email' => 'one@example.com', 'id' => 1, 'username' => 'one' },
        'get view-of',
    ) or Test::More::diag( Test::More::explain( $got ) );
    $got = $backend->list( 'usermini', { username => 'one' } );
    Test::More::is_deeply(
        $got,
        {
            items => [ { 'email' => 'one@example.com', 'id' => 1, 'username' => 'one' } ],
            total => 1,
        },
        'list view-of',
    ) or Test::More::diag( Test::More::explain( $got ) );
    $got = $backend->get( 'userviewnoprops', 'one' );
    Test::More::like(
        $got->{created},
        qr{^\d{4}-\d{2}-\d{2}},
        'created is set by database',
    ) or Test::More::diag( Test::More::explain( $got ) );
    delete $got->{created};
    Test::More::is_deeply(
        $got,
        \%user_one,
        'get viewnoprops',
    ) or Test::More::diag( Test::More::explain( $got ) );
    my %blog_one = $insert_item->( 'blog',
        title => 'T 1',
        username => $user_one{username},
        markdown => '# Super',
        html => '<h1>Super</h1>',
        slug => 't-1',
        published_date => '2020-01-01 00:00:00',
    );
    my %blog_two = $insert_item->( 'blog',
        title => 'T 2',
        username => $user_one{username},
        markdown => '# Smashing',
        html => '<h1>Smashing</h1>',
        slug => 't-2',
        published_date => '2020-01-01 00:00:00',
    );
    $blog_one{is_published} = $blog_two{is_published} = 0;
    my %blog_three = (
        title => 'T 3',
        username => $user_two{username},
        markdown => '# Great',
        html => '<h1>Great</h1>',
        slug => 't-3',
        published_date => '2020-01-01 00:00:00',
    );
    Test::More::subtest( 'booleans etc' => \&test_backend, $backend,
        blog => $schema->{ blog }, # schema
        'markdown', # list key
        [ \%blog_one, \%blog_two ], # List (already in backend)
        'string',
        \%blog_three, # Create/Delete test
        { is_published => 0 }, # create overlay
        { is_published => 1 }, # Set test
        );

    if ( !$backend->supports( 'complex-type' ) ) {
        eval { $backend->set( 'user', $user_two{username}, { comments => [] } ) };
        Test::More::like $@, qr/No refs/, 'set blows up with array-ref data';
        eval { $backend->create( 'user', { comments => [] } ) };
        Test::More::like $@, qr/No refs/, 'create blows up with array-ref data';
    }
    else {
        eval { $backend->set( 'user', $user_two{username}, { comments => [] } ) };
        Test::More::ok !$@, 'set does not blow up with array-ref data'
            or $tb->diag( $@ );
        eval { $backend->create( 'user', { username => 'commentor', comments => [] } ) };
        Test::More::ok !$@, 'create does not blow up with array-ref data'
            or $tb->diag( $@ );
    }

    eval { $backend->set( 'blog', $blog_two{id}, { is_published => 0 } ) };
    Test::More::is $@, '', 'set fine with JSON boolean';

    Test::More::subtest( 'composite key' => sub {
        my %schema = load_fixtures( 'composite-key' );
        my ( $backend_url, $be ) = init_backend( \%schema );

        # Note: Not all databases support a way to get enough data back
        # during the INSERT, so some databases must be provided with all
        # the information in the PRIMARY KEY to satisfy Yancy's
        # requirement that the create() method return the key.
        # Individual differences are tested in the individual backend
        # test scripts.

        # Create item returns both parts of the key
        my $mom_id = $be->create( wiki_pages => {
            wiki_page_id => 1,
            revision_date => '2020-01-01 00:00:00',
            title => 'MomCorp',
            slug => 'MomCorp',
            content => 'Big and evil',
        });
        $tb->is_eq( ref $mom_id, 'HASH', 'create() with composite key returns hashref' );
        $tb->is_num( $mom_id->{wiki_page_id}, 1, 'ID is correct' );
        $tb->is_eq( $mom_id->{revision_date}, '2020-01-01 00:00:00', 'Revision date is correct' );

        my $planex_id = $be->create( wiki_pages => {
            wiki_page_id => 2,
            revision_date => '2020-01-01 00:00:00',
            title => 'PlanetExpress',
            slug => 'PlanetExpress',
            content => 'Small and neutral',
        });
        $tb->is_eq( ref $planex_id, 'HASH', 'create() with composite key returns hashref' );
        $tb->is_num( $planex_id->{wiki_page_id}, 2, 'ID is correct' );
        $tb->is_eq( $planex_id->{revision_date}, '2020-01-01 00:00:00', 'Revision date is given' );

        # Get item with both parts of the key
        my $got = $be->get( wiki_pages => $planex_id );
        $tb->is_eq( $got->{title}, 'PlanetExpress', 'got the right item back' );

        # Set item with both parts of the key
        $tb->ok( $be->set( wiki_pages => $mom_id, { content => 'The big enchirito' } ), 'set() returns success' );
        $tb->is_eq(
            $be->get( wiki_pages => $mom_id )->{content},
            'The big enchirito',
            'set(): content is updated'
        );

        # Create a new revision
        my $revision_id = $be->create( wiki_pages => {
            title => 'MomCorp',
            slug => 'MomCorp',
            content => 'Still big and evil',
            wiki_page_id => $mom_id->{wiki_page_id},
            revision_date => '2525-01-01 00:00:00',
        });
        $tb->is_eq( ref $revision_id, 'HASH', 'create() with composite key returns hashref' );
        $tb->is_eq( $revision_id->{wiki_page_id}, $mom_id->{wiki_page_id}, 'ID is the same' );
        $tb->is_eq( $revision_id->{revision_date}, '2525-01-01 00:00:00', 'Revision date is given' );

        #; $tb->diag( $tb->explain( $Yancy::Backend::Test::DATA{ wiki_pages } ) );

        # List items
        $got = $be->list( 'wiki_pages' );
        $tb->is_num( $got->{total}, 3, '3 items returned' );
        $tb->is_eq(
            join( ', ', sort map { $_->{title} } @{ $got->{items} } ),
            join( ', ', 'MomCorp', 'MomCorp', 'PlanetExpress' ),
            'items returned are correct',
        );

        # Delete item with both parts of the key
        $tb->ok( $be->delete( wiki_pages => $mom_id ), 'delete succeeds' );
        $tb->ok( !$be->get( wiki_pages => $mom_id ), 'item is deleted' );
        $tb->ok( $be->get( wiki_pages => $revision_id ), 'revision is not deleted' );

        # Get item with only one part of the key dies
        eval { $be->get( wiki_pages => { wiki_page_id => $mom_id->{wiki_page_id} } ) };
        $tb->ok( $@, 'get() without full key dies' );
        eval { $be->get( wiki_pages => $mom_id->{wiki_page_id} ) };
        $tb->ok( $@, 'get() with single string dies' );

        # Set item with only one part of the key dies
        eval { $be->set( wiki_pages => { wiki_page_id => $mom_id->{wiki_page_id} }, {} ) };
        $tb->ok( $@, 'set() without full key dies' );
        eval { $be->set( wiki_pages => $mom_id->{wiki_page_id} ) };
        $tb->ok( $@, 'set() with single string dies' );

        # Delete item with only one part of the key dies
        eval { $be->delete( wiki_pages => { wiki_page_id => $mom_id->{wiki_page_id} } ) };
        $tb->ok( $@, 'delete() without full key dies' );
        eval { $be->delete( wiki_pages => $mom_id->{wiki_page_id} ) };
        $tb->ok( $@, 'delete() with single string dies' );
    } );

    Test::More::subtest( 'binary columns' => sub {
        my %schema = load_fixtures( 'binary' );
        local %Yancy::Backend::Test::SCHEMA = %schema;
        my ( $backend_url, $be ) = init_backend( \%schema );
        my ( $schema ) = $be->read_schema( 'icons' );
        $tb->is_eq(
            $schema->{properties}{icon_data}{format}, 'binary',
            'read_schema() identifies binary column',
        );
    });
}

=sub load_fixtures

    my %schema = load_fixtures( 'foreign-key-field', 'auth' );

Load the given test fixtures for the database we're currently testing
(loaded from L</init_backend> using the C<TEST_YANCY_BACKEND>
environment variable). Test fixtures are directories with the given
files:

    schema.json     - The JSON schema
    *.sql           - The SQL schema, named for the backend ("sqlite", "pg", "mysql")

Returns the combined schema ready to be passed-in to a backend or the
Yancy plugin.

=cut

my %driver = (
    sqlite => 'SQLite',
    pg => 'Pg',
    mysql => 'mysql',
);
sub load_fixtures {
    my ( @fixtures ) = @_;
    my %schema;

    for my $fixture ( @fixtures ) {
        my $fixture_dir = curfile->dirname->dirname->sibling( 'fixtures', $fixture );

        # If we're using a database, execute the SQL files
        if ( $ENV{TEST_YANCY_BACKEND} && $ENV{TEST_YANCY_BACKEND} !~ /^test:/ ) {
            my ( $backend, $host, $database )
                = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
            my ( $user, $pass );
            if ( $host ) {
                ( $user, $pass, $host )
                    = $host =~ m{(?:([^:@]+)(?::([^@]+))?@)?(.+)};
            }
            if ( -e $fixture_dir->child( "$backend.sql" ) ) {
                my $sql = $fixture_dir->child( "$backend.sql" )->slurp;
                my $dsn = join ':', 'dbi', $driver{ $backend },
                    join ';', ( $host ? "host=$host" : '' ), "dbname=$database";
                require DBI;
                my $dbh = DBI->connect( $dsn, $user, $pass, { RaiseError => 1 } )
                    or die $DBI::errstr;
                my @statements = split /;\s*(?=CREATE|DROP)/sm, $sql;
                $dbh->do( $_ ) or die $dbh->errstr for @statements;
            }
            elsif ( -e $fixture_dir->child( "$backend.pl" ) ) {
                require $fixture_dir->child( "$backend.pl" );
            }
        }

        # Read the schema file
        %schema = (
            %schema,
            %{ decode_json( $fixture_dir->child( 'schema.json' )->slurp ) },
        );
    }

    return %schema;
}

1;
