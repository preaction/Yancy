
=head1 DESCRIPTION

This tests the L<Yancy::Util> module's exported functions.

=cut

use Mojo::Base '-strict';
use Test::More;
use Yancy::Util qw( load_backend curry currym copy_inline_refs match fill_brackets );
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
        username => 'doug',
        access => 'admin',
        email => 'preaction@cpan.org',
    );

    ok match( { }, \%item ),
        'no tests matches';
    ok match( { access => 'admin' }, \%item ),
        'string eq -- true';
    ok !match( { access => 'user' }, \%item ),
        'string eq -- false';

    ok match( { username => [ qw( doug joel ) ] }, \%item ),
        'array "OR" match -- true';
    ok !match( { username => [ qw( brittany joel ) ] }, \%item ),
        'array "OR" match -- false';

    ok match( { email => { -like => '%@cpan.org' } }, \%item ),
        '-like match -- true';
    ok !match( { email => { -like => '%@gmail.com' } }, \%item ),
        '-like match -- false';
};

subtest 'fill_brackets' => sub {
    my %item = (
        name => 'Doug Bell',
        email => 'doug@example.com',
    );
    is fill_brackets( '{ name } <{email}>', \%item ), 'Doug Bell <doug@example.com>',
        'simple template string is filled in';
};

done_testing;
