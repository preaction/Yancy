
=head1 DESCRIPTION

This tests the L<Yancy::Backend::Test> module which uses
in-memory storage and mimics SQL capabilities.

It deletes from its environment the variable C<TEST_YANCY_BACKEND>
to ensure the right backend is used.

=head1 SEE ALSO

C<t/lib/Local/Test.pm>, L<Yancy>

=cut

use Mojo::Base '-strict';
use Test::More;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use lib catdir( $Bin, '..', 'lib' );
use Local::Test qw( backend_common init_backend );

my $collections = \%Yancy::Backend::Test::SCHEMA;

use Yancy::Backend::Test;

delete $ENV{TEST_YANCY_BACKEND};
my $be;

subtest 'new' => sub {
    ( my $backend_url, $be ) = init_backend( $collections );
    isa_ok $be, 'Yancy::Backend::Test';
    is_deeply $be->collections, $collections;
};

sub insert_item {
    my ( $coll, %item ) = @_;
    my $inserted_id = $be->create( $coll, \%item );
    %{ $be->get( $coll, $inserted_id ) };
}

backend_common( $be, \&insert_item, $collections );

done_testing;
