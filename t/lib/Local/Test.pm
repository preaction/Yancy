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
our @EXPORT_OK = qw( test_backend init_backend );

=sub init_backend

    my ( $backend, $url ) = init_backend( @items );

Initialize a backend for testing with the given items. This routine will
check the C<TEST_YANCY_BACKEND> environment variable for connection
details, if any. Otherwise, it will create a L<Yancy::Backend::Test>
object for mock testing.

=cut

my %to_delete;
my $backend;
sub init_backend {
    my ( $collections, %items ) = @_;
    my %out_items;
    my $backend_url = $ENV{TEST_YANCY_BACKEND} || 'test://localhost';
    $backend = load_backend( $backend_url, $collections );
    for my $collection ( keys %items ) {
        for my $item ( @{ $items{ $collection } } ) {
            my $item = $backend->create( $collection, $item );
            push @{ $out_items{ $collection } }, $item;
            push @{ $to_delete{ $collection } },
                $item->{ $collections->{ $collection }{ 'x-id-field' } // 'id' };
        }
    }
    return ( $backend_url, $backend, %out_items );
}

END {
    for my $coll ( keys %to_delete ) {
        $backend->delete( $coll, $_ ) for @{ $to_delete{ $coll } };
    }
};

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
    my ( $be, $coll_name, $coll_conf, $list, $create, $set_to ) = @_;
    my $id_field = $coll_conf->{ 'x-id-field' } || 'id';
    my $tb = Test::Builder->new();

    $tb->subtest( 'list' => sub {
        my $got_list = $be->list( $coll_name );
        Test::More::is_deeply(
            $got_list,
            { rows => $list, total => scalar @$list },
            'list all items is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { offset => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ @{ $list }[1..$#$list] ], total => scalar @$list },
            'list with offset is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { limit => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ $list->[0] ], total => scalar @$list },
            'list with limit is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { offset => 1, limit => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ $list->[1] ], total => scalar @$list },
            'list with offset/limit is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        my $key = $list->[0]{name} ? 'name'
                : $list->[0]{username} ? 'username'
                : die "Can't find column for search (name, username)";
        my $value = $list->[0]{ $key };
        my @expect_list = grep { $_->{ $key } eq $value } @{ $list };

        $got_list = $be->list( $coll_name, { $key => $value } );
        Test::More::is_deeply(
            $got_list,
            { rows => \@expect_list, total => scalar @expect_list },
            'list with search equals is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $value = substr $list->[0]{ $key }, 0, 4;
        @expect_list = grep { $_->{ $key } =~ /^$value/ } @{ $list };
        $value .= '%';
        $got_list = $be->list( $coll_name, { $key => { like => $value } } );
        Test::More::is_deeply(
            $got_list,
            { rows => \@expect_list, total => scalar @expect_list },
            'list with search starts with is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $value = substr $list->[0]{ $key }, -4;
        @expect_list = grep { $_->{ $key } =~ /$value$/ } @{ $list };
        $value = '%' . $value;
        $got_list = $be->list( $coll_name, { $key => { like => $value } } );
        Test::More::is_deeply(
            $got_list,
            { rows => \@expect_list, total => scalar @expect_list },
            'list with search ends with is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        @expect_list = sort { $a->{ $key } cmp $b->{ $key } } @{ $list };
        $got_list = $be->list( $coll_name, {}, { order_by => { -asc => $key } } );
        Test::More::is_deeply(
            $got_list,
            { rows => \@expect_list, total => scalar @expect_list },
            'list with order by asc is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        @expect_list = sort { $b->{ $key } cmp $a->{ $key } } @{ $list };
        $got_list = $be->list( $coll_name, {}, { order_by => { -desc => $key } } );
        Test::More::is_deeply(
            $got_list,
            { rows => \@expect_list, total => scalar @expect_list },
            'list with order by desc is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );
    } );

    $tb->subtest( 'get' => sub {
        my $got = $be->get( $coll_name => $list->[0]{ $id_field } );
        Test::More::is_deeply( $got, $list->[0], 'created item correct' )
            or $tb->diag( $tb->explain( $got ) );
    });

    $tb->subtest( 'create' => sub {
        my $got = $be->create( $coll_name => $create );
        $create->{ $id_field } = $got->{ $id_field };
        Test::More::is_deeply( $got, $create, 'created item correct' )
            or $tb->diag( $tb->explain( $got ) );
    });

    $tb->subtest( 'set' => sub {
        $be->set( $coll_name => $create->{ $id_field } => $set_to );
        $set_to->{ $id_field } = $create->{ $id_field };
        Test::More::is_deeply(
            $be->get( $coll_name, $create->{ $id_field } ), $set_to,
        );
    });

    $tb->subtest( 'delete' => sub {
        $be->delete( $coll_name => $create->{ $id_field } );
        $tb->ok( !$be->get( $coll_name, $create->{ $id_field } ),
            'deleted item not found',
        );
    });

    $tb->subtest( read_schema => sub {
        my $got_schema = $be->read_schema;
        my $expect_schema = {
            people => {
                required => [qw( name )],
                properties => {
                    id => { type => 'integer', 'x-order' => 1 },
                    name => { type => 'string', 'x-order' => 2 },
                    email => { type => [ 'string', 'null' ], 'x-order' => 3 },
                },
            },
            user => {
                required => [qw( username email )],
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string', 'x-order' => 1 },
                    email => { type => 'string', 'x-order' => 2 },
                    access => {
                        type => 'string',
                        enum => [qw( user moderator admin )],
                        'x-order' => 3,
                    },
                },
            },
        };
        Test::More::is_deeply(
            $got_schema, $expect_schema, 'schema read from database is correct',
        );
    });
};

1;
