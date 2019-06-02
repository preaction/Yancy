
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

my $schema = \%Yancy::Backend::Test::SCHEMA;

use Yancy::Backend::Test;

delete $ENV{TEST_YANCY_BACKEND};
my $be;

subtest 'new' => sub {
    ( my $backend_url, $be ) = init_backend( $schema );
    isa_ok $be, 'Yancy::Backend::Test';
    is_deeply $be->schema, $schema;
};

sub insert_item {
    my ( $schema_name, %item ) = @_;
    my $inserted_id = $be->create( $schema_name, \%item );
    %{ $be->get( $schema_name, $inserted_id ) };
}

backend_common( $be, \&insert_item, $schema );

done_testing;
