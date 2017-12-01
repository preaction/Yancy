package Local::Test;

=head1 SYNOPSIS

    use Test::More;
    use Local::Test qw( test_backend );

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

use v5.24;
use experimental qw( signatures postderef );
use Exporter 'import';
use Test::Builder;
use Test::More ();
our @EXPORT_OK = qw( test_backend );

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

sub test_backend( $be, $coll_name, $coll_conf, $list, $create, $set_to ) {
    my $id_field = $coll_conf->{ 'x-id-field' } || 'id';
    my $tb = Test::Builder->new();

    $tb->subtest( 'list' => sub {
        my $got_list = $be->list( $coll_name );
        Test::More::is_deeply(
            $got_list,
            { rows => $list, total => scalar @$list },
            'list is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { offset => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ $list->@[1..$#$list] ], total => scalar @$list },
            'list is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { limit => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ $list->[0] ], total => scalar @$list },
            'list is correct'
        ) or $tb->diag( $tb->explain( $got_list ) );

        $got_list = $be->list( $coll_name, {}, { offset => 1, limit => 1 } );
        Test::More::is_deeply(
            $got_list,
            { rows => [ $list->[1] ], total => scalar @$list },
            'list is correct'
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

};

1;
