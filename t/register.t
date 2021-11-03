
=head1 DESCRIPTION

This tests registering the Mojolicious::Plugin::Yancy and the various kinds
of arguments that can be given.

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Yancy;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my ( $backend_url, $backend, %items ) = init_backend( {} );

subtest 'sqlite' => sub {
    if ( !eval { require Yancy::Backend::Sqlite; 1 } ) {
        diag $@;
        pass 'skipped: Mojo::SQLite required';
        return;
    }

    subtest 'bare sqlite database (Mojo::SQLite)' => sub {
        my $app = Mojolicious->new;
        my $db = Mojo::SQLite->new( 'sqlite::memory:' );
        eval { $app->plugin( Yancy => backend => $db ) };
        ok !$@, 'plugin is loaded' or diag $@;
        isa_ok $app->yancy->backend, 'Yancy::Backend::Sqlite', 'backend object is correct';
    };
};

subtest 'postgresql' => sub {
    if ( !eval { require Yancy::Backend::Pg; 1 } ) {
        diag $@;
        pass 'skipped: Mojo::Pg required';
        return;
    }

    subtest 'postgresql database (Mojo::Pg)' => sub {
        my $app = Mojolicious->new;
        my $db = bless {}, 'Mojo::Pg';
        eval { $app->plugin( Yancy => backend => $db, read_schema => 0 ) };
        ok !$@, 'plugin is loaded' or diag $@;
        isa_ok $app->yancy->backend, 'Yancy::Backend::Pg', 'backend object is correct';
    };
};

subtest 'mysql' => sub {
    if ( !eval { require Yancy::Backend::Mysql; 1 } ) {
        diag $@;
        pass 'skipped: Mojo::mysql required';
        return;
    }

    subtest 'mysql database (Mojo::Mysql)' => sub {
        my $app = Mojolicious->new;
        my $db = Mojo::mysql->new();
        eval { $app->plugin( Yancy => backend => $db, read_schema => 0 ) };
        ok !$@, 'plugin is loaded' or diag $@;
        isa_ok $app->yancy->backend, 'Yancy::Backend::Mysql', 'backend object is correct';
    };
};

done_testing;
