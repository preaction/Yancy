package Local::Test;

=head1 SYNOPSIS

    use Test::More;
    use Local::Test qw( test_backend init_backend );

    subtest 'test my backend' => \&test_backend, $backend_object,
        collection => { ... },
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
use Mojo::JSON qw( true );

our @EXPORT_OK = qw( test_backend init_backend backend_common );

=sub init_backend

    my ( $backend, $url ) = init_backend( @items );

Initialize a backend for testing with the given items. This routine will
check the C<TEST_YANCY_BACKEND> environment variable for connection
details, if any. Otherwise, it will create a L<Yancy::Backend::Test>
object for mock testing.

B<NOTE>: This routine will delete all existing data in the given
collections!

=cut

my %to_delete;
my $backend;
sub init_backend {
    my ( $collections, %items ) = @_;
    my %out_items;
    my $backend_url = $ENV{TEST_YANCY_BACKEND} || 'test://localhost';
    $backend = load_backend( $backend_url, $collections );
    for my $collection ( keys %$collections ) {
        my $id_field = $collections->{ $collection }{ 'x-id-field' } // 'id';
        for my $item ( @{ $backend->list( $collection )->{items} } ) {
            $backend->delete( $collection, $item->{ $id_field } );
        }
    }
    for my $collection ( keys %items ) {
        my $id_field = $collections->{ $collection }{ 'x-id-field' } // 'id';
        for my $item ( @{ $items{ $collection } } ) {
            my $id = $backend->create( $collection, $item );
            $item->{ $id_field } = $id;
            $item = $backend->get( $collection, $id );
            push @{ $out_items{ $collection } }, $item;
            push @{ $to_delete{ $collection } }, $id;
        }
    }
    return ( $backend_url, $backend, %out_items );
}

END {
    for my $coll ( keys %to_delete ) {
        eval { $backend->delete( $coll, $_ ) } for @{ $to_delete{ $coll } };
    }
};

# This is only for when the Test backend is being used and is
# ignored when TEST_YANCY_BACKEND is set to something else
%Yancy::Backend::Test::SCHEMA = (
    blog => {
        type => 'object',
        properties => {
            id => {
              'x-order' => 1,
              readOnly => true,
              type => 'integer',
            },
            user_id => {
              'x-order' => 2,
              type => [ 'integer', 'null' ],
            },
            title => {
              'x-order' => 3,
              type => [ 'string', 'null' ],
            },
            slug => {
              'x-order' => 4,
              type => [ 'string', 'null' ],
            },
            markdown => {
              'x-order' => 5,
              type => [ 'string', 'null' ],
            },
            html => {
              type => [ 'string', 'null' ],
              'x-order' => 6,
            },
            is_published => {
              type => 'boolean',
              'x-order' => 7,
            },
        },
    },
    mojo_migrations => {
        type => 'object',
        required => [qw( name version )],
        'x-id-field' => 'name',
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
            },
            password => {
                'x-order' => 4,
                type => 'string',
            },
            access => {
                'x-order' => 5,
                type => 'string',
                enum => [qw( user moderator admin )],
            },
            age => {
                'x-order' => 6,
                type => [qw( integer null )],
            },
        },
    },
);

=sub test_backend

    my $result = test_backend(
        $backend, $coll_name, $coll_conf,
        $list, $create, $set_to,
    );

Test that a backend works properly. C<$backend> is a backend object.
C<$coll_name> is the collection name to test. C<$coll_conf> is the collection
configuration (JSON schema). C<$list> is a list of objects already in the
backend. C<$create> is a new object to test creating an object. C<$set_to>
is values the newly-create object will be set to, before being deleted.

=cut

sub test_backend {
    my ( $be, $coll_name, $coll_conf, $list_key, $list, $create, $create_overlay, $set_to ) = @_;
    my $id_field = $coll_conf->{ 'x-id-field' } || 'id';
    my $tb = Test::Builder->new();

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
                    Test::More::is_deeply( $got, $create, 'created item correct' )
                        or $tb->diag( $tb->explain( $got ) );
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
                    Test::More::is_deeply( $got, { %$create, %$set_to }, 'set item correct' )
                        or $tb->diag( $tb->explain( $got ) );
                } )->wait;
            },
        },

        {
            name => 'set (failure)',
            method => 'set',
            args => [ $coll_name => '99999' => $set_to ],
            test => sub {
                my ( $not_ok ) = @_;
                Test::More::ok( !$not_ok, 'set() returns boolean false if row not modified' );
            },
        },

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
                Test::More::is_deeply( $got, $test->{expect} )
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
                    contact => { type => [ 'boolean', 'null' ], 'x-order' => 5 },
                    phone => { type => [ 'string', 'null' ], 'x-order' => 6 },
                },
            },
            user => {
                type => 'object',
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
                    },
                    age => {
                        type => [ 'integer', 'null' ],
                        'x-order' => 6,
                    },
                },
            },
            blog => {
                type => 'object',
                properties => {
                    id => { type => 'integer', 'x-order' => 1, readOnly => true },
                    user_id => { type => [ 'integer', 'null' ], 'x-order' => 2 },
                    title => { type => [ 'string', 'null' ], 'x-order' => 3 },
                    slug => { type => [ 'string', 'null' ], 'x-order' => 4 },
                    markdown => { type => [ 'string', 'null' ], 'x-order' => 5 },
                    html => { type => [ 'string', 'null' ], 'x-order' => 6 },
                    is_published => { type => 'boolean', 'x-order' => 7 },
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

        # The DBIC backend doesn't ignore modules from read_schema,
        # since people don't create DBIC result classes for things they
        # don't want to interact with...
        if ( !$got_schema->{mojo_migrations}{'x-ignore'} ) {
            delete $expect_schema->{mojo_migrations}{'x-ignore'};
        }

        Test::More::is_deeply(
            $got_schema, $expect_schema, 'schema read from database is correct',
        ) or $tb->diag( $tb->explain( $got_schema ) );

        $tb->subtest( 'schema validates with JSON::Validator' => sub {
            my $v = JSON::Validator->new(
                coerce => { booleans => 1, numbers => 1 },
            );
            $v->formats->{ markdown } = sub { 1 };
            $v->formats->{ tel } = sub { 1 };
            $v->schema( $expect_schema->{ $coll_name } );

            my $got = $be->get( $coll_name => $list->[0]{ $id_field } );
            my @errors = $v->validate( $got );
            $tb->ok( !@errors, 'no validation errors' )
                or $tb->diag( $tb->explain( \@errors ) );
        } );

        my $got_table = $be->read_schema( 'people' );
        Test::More::is_deeply(
            $got_table, $expect_schema->{ people },
            'single schema read from database is correct',
        ) or $tb->diag( $tb->explain( $got_table ) );

    });

}

=sub backend_common

    backend_common( $backend, \&insert_item, $collections );

Runs various tests on the given L<Yancy::Backend> instance. The code is
a backend-specific procedure to create items, probably a closure.

=cut

sub backend_common {
    my ( $backend, $insert_item, $collections ) = @_;
    my %person_one = $insert_item->( people =>
        name => 'person One',
        email => 'one@example.com',
        age => undef, contact => undef, phone => undef,
    );
    my %person_two = $insert_item->( people =>
        name => 'person Two',
        email => 'two@example.com',
        age => undef, contact => undef, phone => undef,
    );
    my %person_three = (
        name => 'person Three',
        email => 'three@example.com',
        age => undef, contact => undef, phone => undef,
    );
    Test::More::subtest( 'default id field' => \&test_backend, $backend,
        people => $collections->{ people }, # Collection
        'name', # list key
        [ \%person_one, \%person_two ], # List (already in backend)
        \%person_three, # Create/Delete test
        {}, # create overlay
        { name => 'Set' }, # Set test
        );
    my %user_one = $insert_item->( 'user',
        username => 'one',
        email => 'one@example.com',
        access => 'user',
        password => 'p1',
        age => undef,
    );
    my %user_two = $insert_item->( 'user',
        username => 'two',
        email => 'two@example.com',
        access => 'moderator',
        password => 'p2',
        age => undef,
    );
    my %user_three = (
        username => 'three',
        email => 'three@example.com',
        access => 'admin',
        password => 'p3',
        age => undef,
    );
    Test::More::subtest( 'custom id field' => \&test_backend, $backend,
        user => $collections->{ user }, # Collection
        'username', # list key
        [ \%user_one, \%user_two ], # List (already in backend)
        \%user_three, # Create/Delete test
        {}, # create overlay
        { email => 'test@example.com' }, # Set test
        );
    my %blog_one = $insert_item->( 'blog',
        title => 'T 1',
        user_id => $user_one{id},
        markdown => '# Super',
        html => '<h1>Super</h1>',
        slug => 't-1',
    );
    my %blog_two = $insert_item->( 'blog',
        title => 'T 2',
        user_id => $user_one{id},
        markdown => '# Smashing',
        html => '<h1>Smashing</h1>',
        slug => 't-2',
    );
    $blog_one{is_published} = $blog_two{is_published} = 0;
    my %blog_three = (
        title => 'T 3',
        user_id => $user_two{id},
        markdown => '# Great',
        html => '<h1>Great</h1>',
        slug => 't-3',
    );
    Test::More::subtest( 'booleans etc' => \&test_backend, $backend,
        blog => $collections->{ blog }, # Collection
        'markdown', # list key
        [ \%blog_one, \%blog_two ], # List (already in backend)
        \%blog_three, # Create/Delete test
        { is_published => 0 }, # create overlay
        { is_published => 1 }, # Set test
        );
}

1;
