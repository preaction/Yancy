
=head1 DESCRIPTION

This tests the L<Yancy::Command::backend::copy> command.

=head1 SEE ALSO

L<Yancy::Command::backend>

=cut

use Mojo::Base -strict;
use Test::More;
use Mojo::JSON qw( true false decode_json );
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Yancy;
use Yancy::Command::backend::copy;

use Local::Test qw( init_backend );
my $collections = \%Yancy::Backend::Test::SCHEMA;
my %data = (
    people => [
        {
            id => 1,
            name => 'Doug Bell',
            email => 'doug@example.com',
            age => 35,
            contact => '1',
            phone => undef,
        },
        {
            id => 2,
            name => 'Joel Berger',
            email => 'joel@example.com',
            age => 51,
            contact => '0',
            phone => undef,
        },
    ],
);
$ENV{MOJO_HOME} = path( $Bin, 'share' ); # to dodge any yancy.conf in root
my ( $backend_url, $backend, %items ) = init_backend( $collections, %data );
my $app = Yancy->new(
    config => {
        backend => $backend_url,
        collections => $collections,
    },
);

my $cmd = Yancy::Command::backend::copy->new(
    app => $app,
);

my $dest_url = 'test://';
$cmd->run( $dest_url, 'people', 'person' );

my $dest_data = $Yancy::Backend::Test::COLLECTIONS{ person };
ok $dest_data, 'got dest data';
is scalar keys %$dest_data, 2, '2 rows copied';
is_deeply
    $dest_data,
    { map { $_->{id} => $_ } @{ $data{people} } },
    'row data copied correctly';

done_testing;
