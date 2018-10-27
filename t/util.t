
=head1 DESCRIPTION

This tests the L<Yancy::Util> module's exported functions.

=cut

use Mojo::Base '-strict';
use Test::More;
use Yancy::Util qw( load_backend curry currym );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );

my $collections = {
    foo => {},
};

subtest 'load_backend' => sub {
    subtest 'load_backend( $url )' => sub {
        my $backend = load_backend( 'test://localhost', $collections );
        isa_ok $backend, 'Yancy::Backend::Test';
        is $backend->{init_arg}, 'test://localhost', 'backend got init arg';
        is_deeply $backend->{collections}, $collections;
    };

    subtest 'load_backend( { $type => $arg } )' => sub {
        my $backend = load_backend( { test => [qw( foo bar )] }, $collections );
        isa_ok $backend, 'Yancy::Backend::Test';
        is_deeply $backend->{init_arg}, [qw( foo bar )], 'backend got init arg';
        is_deeply $backend->{collections}, $collections;
    };

    subtest 'load invalid backend class' => sub {
        eval { load_backend( 'INVALID://localhost', $collections ) };
        ok $@, 'exception is thrown';
        like $@, qr{Could not find class Yancy::Backend::INVALID},
            'error is correct';
    };

    subtest 'load broken backend class' => sub {
        eval { load_backend( 'brokentest://localhost', $collections ) };
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

done_testing;
