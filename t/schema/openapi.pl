=head1 DESCRIPTION

Script to regenerate F<t/share/openapi-spec.json>. Run:

  perl t/schema/openapi.pl

=cut

use Mojo::Base '-strict';
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' ); # t/lib
use lib "".path( $Bin, '..', '..', 'lib' ); # top lib
use Local::Test qw( init_backend );

my $schema = \%Local::Test::SCHEMA;
my ( $backend_url ) = init_backend( $schema );
my $t = Test::Mojo->new(
    'Yancy',
    { backend => $backend_url, schema => $schema, editor => { require_user => 0 } },
);

my $data = $t->ua->get( '/yancy/api' )->result->json;
delete @$data{ qw(x-bundled host schemes produces consumes basePath) };
for my $op (grep defined, map @$_{qw(get post put delete)}, values %{$data->{paths}}) {
    # zap inserted "default" responses as default already covers
    my $r = $op->{responses};
    delete $r->{$_} for grep $r->{$_}{description} =~ /^Default/, keys %$r;
    delete $op->{'x-mojo-to'};
}
# XXX if do this, then blows up with id=joe/. That's probably correct
# per OpenAPI spec
#for my $params (grep defined, map $_->{parameters}, values %{$data->{paths}}) {
#    delete $_->{'x-mojo-placeholder'} for @$params;
#}
my $encoder = JSON::PP->new->ascii->pretty->canonical;
path ( $Bin, qw(.. share openapi-spec.json) )->spurt( $encoder->encode($data) );
