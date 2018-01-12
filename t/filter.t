
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

use Yancy::Backend::Test;
%Yancy::Backend::Test::COLLECTIONS = (
    users => {
        doug => {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest,
        },
        joel => {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-1' )->add( '456rty' )->b64digest,
        },
    },
);
%Yancy::Backend::Test::SCHEMA = (
    people => {
        required => [qw( name )],
        properties => {
            name => { type => 'string' },
            email => { type => 'string' },
        },
    },
    users => {
        'x-id-field' => 'username',
        required => [qw( username )],
        properties => {
            username => { type => 'string' },
            email => { type => 'string' },
            password => { type => 'string' },
        },
    },
);


$ENV{MOJO_CONFIG} = path( $Bin, '/share/config.pl' );

my $t = Test::Mojo->new( 'Yancy' );
$t->app->config->{collections}{users}{properties}{password}{'x-filter'} = [ 'test.digest' ];
$t->app->config->{collections}{users}{properties}{password}{'x-digest'} = { type => 'SHA-1' };

subtest 'register and run a filter' => sub {
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
    my $filtered_user = $t->app->yancy->filter->apply( users => $user );
    is $filtered_user->{username}, $user->{username}, 'no filter, no change';
    is $filtered_user->{email}, $user->{email}, 'no filter, no change';
    is $filtered_user->{password},
        Digest->new( 'SHA-1' )->add( 'unfiltered' )->b64digest,
        'filter is executed';
};

subtest 'api runs filters during set' => sub {
    my $doug = {
        %{ $Yancy::Backend::Test::COLLECTIONS{users}{doug} },
        password => 'qwe123',
    };
    $t->put_ok( '/yancy/api/users/doug', json => $doug )
      ->status_is( 200 );
    is $Yancy::Backend::Test::COLLECTIONS{users}{doug}{password},
        Digest->new( 'SHA-1' )->add( 'qwe123' )->b64digest,
        'new password is digested correctly'
};

subtest 'api runs filters during create' => sub {
    my $new_user = {
        username => 'qubert',
        email => 'qubert@example.com',
        password => 'stalemate',
    };
    $t->post_ok( '/yancy/api/users', json => $new_user )
      ->status_is( 201 );
    is $Yancy::Backend::Test::COLLECTIONS{users}{qubert}{password},
        Digest->new( 'SHA-1' )->add( 'stalemate' )->b64digest,
        'new password is digested correctly'
};

done_testing;
