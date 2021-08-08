
=head1 DESCRIPTION

This tests the L<Yancy::Util> module's exported functions.

=cut

use Mojo::Base '-strict';
use Test::More;
use Yancy::Util qw( load_backend curry currym copy_inline_refs match fill_brackets order_by );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );

my $schema = {
    foo => {},
};

subtest 'load_backend' => sub {
    subtest 'load_backend( $url )' => sub {
        my $backend = load_backend( 'test://localhost', $schema );
        isa_ok $backend, 'Yancy::Backend::Test';
        is $backend->{init_arg}, 'test://localhost', 'backend got init arg';
        is_deeply $backend->schema, $schema;
    };

    subtest 'load_backend( { $type => $arg } )' => sub {
        my $backend = load_backend( { test => [qw( foo bar )] }, $schema );
        isa_ok $backend, 'Yancy::Backend::Test';
        is_deeply $backend->{init_arg}, [qw( foo bar )], 'backend got init arg';
        is_deeply $backend->schema, $schema;
    };

    subtest 'load invalid backend class' => sub {
        eval { load_backend( 'INVALID://localhost', $schema ) };
        ok $@, 'exception is thrown';
        like $@, qr{Could not find class Yancy::Backend::INVALID},
            'error is correct';
    };

    subtest 'load broken backend class' => sub {
        eval { load_backend( 'brokentest://localhost', $schema ) };
        ok $@, 'exception is thrown';
        like $@, qr{Could not load class Yancy::Backend::Brokentest: Died},
            'error is correct';
    };
};

subtest 'curry' => sub {
    my $add = sub { $_[0] + $_[1] };
    my $add_four = curry( $add, 4 );
    is ref $add_four, 'CODE', 'curry returns code ref';
    is $add_four->( 1 ), 5, 'curried arguments are passed correctly';
};

subtest 'currym' => sub {
    package Local::TestUtil { sub add { $_[1] + $_[2] } }
    my $obj = bless {}, 'Local::TestUtil';
    my $add_four = currym( $obj, 'add', 4 );
    is ref $add_four, 'CODE', 'curry returns code ref';
    is $add_four->( 1 ), 5, 'curried arguments are passed correctly';

    subtest 'dies if method not found' => sub {
        eval { currym( $obj, 'NOT_FOUND' ) };
        ok $@, 'currym dies if method not found';
        like $@, qr{Can't curry method "NOT_FOUND" on object of type "Local::TestUtil": Method is not implemented},
            'currym exception message is correct';
    };
};

subtest 'copy_inline_refs' => sub {
    my $schema = {
        blog => {
            type => 'object',
            properties => {
                comments => {
                  items => { '$ref' => '#/comment' },
                  type => 'array',
                },
                title => { type => 'string' },
                user => { '$ref' => '#/user' },
            },
        },
        comment => {
            properties => {
                id => { type => 'integer' },
                blog => { '$ref' => '#/blog' },
                user => { '$ref' => '#/user' },
            },
            type => 'object',
        },
        user => {
            type => 'object',
            properties => {
                blogs => {
                    items => { '$ref' => '#/blog' }, type => 'array',
                },
                comments => {
                    items => { '$ref' => '#/comment' },
                    type => 'array',
                },
                id => { type => 'integer' },
            },
        },
        people => {
            type => 'object',
            properties => {
                id => { type => 'integer' },
                name => { type => 'string' },
            },
        },
        people2 => {
            type => 'object',
            properties => {
                id => { type => 'integer' },
                name2 => { '$ref' => '#/people2/properties/id' },
            },
        },
    };
    my $got = copy_inline_refs( $schema, '' );
    is_deeply $got, {
        'blog' => {
            'properties' => {
                'comments' => {
                    'items' => {
                        'properties' => {
                            'blog' => { '$ref' => '#/blog' },
                            'id' => { 'type' => 'integer' },
                            'user' => {
                                'properties' => {
                                    'blogs' => {
                                        'items' => { '$ref' => '#/blog' },
                                        'type' => 'array'
                                    },
                                    'comments' => {
                                        'items' => {
                                            '$ref' => '#/blog/properties/comments/items'
                                        },
                                        'type' => 'array'
                                    },
                                    'id' => { 'type' => 'integer' }
                                },
                                'type' => 'object'
                            }
                        },
                        'type' => 'object'
                    },
                    'type' => 'array'
                },
                'title' => { 'type' => 'string' },
                'user' => {
                    '$ref' => '#/blog/properties/comments/items/properties/user'
                }
            },
            'type' => 'object'
        },
        'comment' => {
            '$ref' => '#/blog/properties/comments/items'
        },
        'people' => {
            'properties' => {
                'id' => { 'type' => 'integer' },
                'name' => { 'type' => 'string' }
            },
            'type' => 'object'
        },
        'people2' => {
            'properties' => {
                'id' => { 'type' => 'integer' },
                'name2' => { '$ref' => '#/people2/properties/id' }
            },
            'type' => 'object'
        },
        'user' => {
            '$ref' => '#/blog/properties/comments/items/properties/user'
        }
    }, 'identity' or diag explain $got;
    $got = copy_inline_refs( $schema, '/people' );
    is_deeply $got, $schema->{people}, 'people' or diag explain $got;
    $got = copy_inline_refs( $schema, '/people2' );
    is_deeply $got, {
        type => 'object',
        properties => {
            id => { type => 'integer' },
            name2 => { '$ref' => '#/properties/id' },
        },
    }, 'people2' or diag explain $got;
    $got = copy_inline_refs( $schema, '/user' );
    is_deeply $got, {
        'properties' => {
            'blogs' => {
                'items' => {
                    'properties' => {
                        'comments' => {
                            'items' => {
                                'properties' => {
                                    'blog' => { '$ref' => '#/properties/blogs/items' },
                                    'id' => { 'type' => 'integer' },
                                    'user' => { '$ref' => '#' }
                                },
                                'type' => 'object'
                            },
                            'type' => 'array'
                        },
                        'title' => { 'type' => 'string' },
                        'user' => { '$ref' => '#' }
                    },
                    'type' => 'object'
                },
                'type' => 'array'
            },
            'comments' => {
                'items' => {
                    '$ref' => '#/properties/blogs/items/properties/comments/items'
                },
                'type' => 'array'
            },
            'id' => { 'type' => 'integer' }
        },
        'type' => 'object'
    }, 'user' or diag explain $got;
};

subtest 'match' => sub {
    my %item = (
        access => 'admin',
        is_online => 0,
        username => 'doug',
        email => 'preaction@cpan.org',
        null => undef,
        roles => [qw( admin moderator user )],
        address => {
            street => '123 Fake St.',
        },
    );

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    ok match( { }, \%item ),
        'no tests matches';
    ok match( { access => 'admin' }, \%item ),
        'string eq -- true';
    ok !match( { access => 'user' }, \%item ),
        'string eq -- false';

    ok !match( {-bool => 'is_online'}, \%item),
        'bool falsey value -- false';
    ok match( {-not_bool => 'is_online'}, \%item),
        'not_bool falsey value -- true';
    ok match( {-bool => 'username'}, \%item),
        'bool truthy value -- true';
    ok !match( {-not_bool => 'username'}, \%item),
        'not_bool truthy value -- false';

    ok match( { username => [ qw( doug joel ) ] }, \%item ),
        'array "OR" match -- true';
    ok !match( { username => [ qw( brittany joel ) ] }, \%item ),
        'array "OR" match -- false';

    ok match( { email => { -like => '%@cpan.org' } }, \%item ),
        '-like match -- true';
    ok !match( { email => { -like => '%@gmail.com' } }, \%item ),
        '-like match -- false';

    ok match( { null => undef }, \%item ),
        'undef (null) match -- true';
    ok !match( { email => undef }, \%item ),
        'undef (null) match -- false';
    ok match( { email => { '!=' => undef } }, \%item ),
        '!= undef (not null) match -- true';
    ok !match( { null => { '!=' => undef } }, \%item ),
        '!= undef (not null) match -- false';
    ok match( { key_not_in_item => {'!=' => 'forbidden_value'}}, \%item ),
        'key_not_in_item != forbidden_value -- true';

    ok !match( { null => 1 }, \%item ),
        'undef != 1 match -- false';
 
    ok match( { roles => { -has => 'admin' } }, \%item ),
        '-has matches scalar against array -- true';
    ok !match( { roles => { -has => 'banned' } }, \%item ),
        '-has matches scalar against array -- false';
    ok match( { roles => { -not_has => 'banned' } }, \%item ),
        '-not_has matches scalar against array -- true';
    ok !match( { roles => { -not_has => 'admin' } }, \%item ),
        '-not_has matches scalar against array -- false';

    ok match( { roles => { -has => [ 'admin', 'moderator' ] } }, \%item ),
        '-has matches array against array -- true';
    ok !match( { roles => { -has => [ 'moderator', 'banned' ] } }, \%item ),
        '-has matches array against array -- true';
    ok match( { roles => { -not_has => [ 'banned', 'missing' ] } }, \%item ),
        '-not_has matches array against array -- true';
    ok !match( { roles => { -not_has => [ 'admin', 'banned' ] } }, \%item ),
        '-not_has matches scalar against array -- false';

    ok match( { address => { -has => { street => '123 Fake St.' } } }, \%item ),
        '-has matches hash against hash -- true';
    ok !match( { address => { -has => { street => '10 Sesame St.' } } }, \%item ),
        '-has matches hash against hash -- false';
    ok match( { address => { -not_has => { street => '10 Sesame St.' } } }, \%item ),
        '-not_has matches hash against hash -- true';
    ok !match( { address => { -not_has => { street => '123 Fake St.' } } }, \%item ),
        '-not_has matches hash against hash -- false';

    ok match( { address => { -has => { street => { -like => '%Fake St.' } } } }, \%item ),
        '-has matches hash containing query against hash -- true';
    ok !match( { address => { -has => { street => { -like => '%Sesame St.' } } } }, \%item ),
        '-has matches hash containing query against hash -- false';
    ok match( { address => { -not_has => { street => { -like => '%Sesame St.' } } } }, \%item ),
        '-not_has matches hash containing query against hash -- true';
    ok !match( { address => { -not_has => { street => { -like => '%Fake St.' } } } }, \%item ),
        '-not_has matches hash containing query against hash -- false';

    ok !eval { match( { null => { -has => [ 'foo' ] } }, \%item ) },
        '-has returns false when value is undef';
    ok !$@, '-has does not die when value is undef';
    ok eval { match( { null => { -not_has => [ 'foo' ] } }, \%item ) },
        '-not_has returns true when value is undef';
    ok !$@, '-not_has does not die when value is undef';

    ok !match( { username => { -like => '%doug%' }, email => { -like => '%doug%' } }, \%item ),
        'hash is AND and does not match';
    ok match( [ { username => { -like => '%doug%' } }, { email => { -like => '%doug%' } } ], \%item ),
        'array is OR and does match';

    ok !defined match({}, undef), 'returns undef for undef item';

    ok !@warnings, 'no warnings issued during test'
        or diag explain \@warnings;
};

subtest 'order_by' => sub {
    my @unordered = (
        { foo => 'bbb', bar => 1 },
        { foo => 'ccc', bar => 5 },
        { foo => 'aaa', bar => 5 },
    );

    is_deeply order_by( 'foo', \@unordered ),
        [ @unordered[ 2, 0, 1 ] ],
        'order_by single field';
    is_deeply order_by( [ 'bar', 'foo' ], \@unordered ),
        [ @unordered[ 0, 2, 1 ] ],
        'order_by array';
    is_deeply order_by( { -desc => 'foo' }, \@unordered ),
        [ @unordered[ 1, 0, 2 ] ],
        'order_by hash';
    is_deeply order_by( [ { -desc => 'bar' }, 'foo' ], \@unordered ),
        [ @unordered[ 2, 1, 0 ] ],
        'order_by array of hashes';
};

subtest 'fill_brackets' => sub {
    my %item = (
        name => 'Doug Bell',
        email => 'doug@example.com',
        quote => '<3',
    );
    is fill_brackets( '{ name } <{email}>', \%item ), 'Doug Bell <doug@example.com>',
        'simple template string is filled in';
    is fill_brackets( '{ quote }', \%item ), '&lt;3', 'unsafe html is escaped';
};

done_testing;
