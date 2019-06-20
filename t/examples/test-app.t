
=head1 DESCRIPTION

This tests an example application in the C<eg/test-app> directory to
make sure it still works with the new version of Yancy.

=head1 SEE ALSO

C<eg/test-app>

=cut

use Mojo::Base '-strict';
use Test::More;

BEGIN {
    plan skip_all => 'Set TEST_YANCY_EXAMPLES to run these tests'
        if !$ENV{TEST_YANCY_EXAMPLES};
}

use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use FindBin qw( $Bin );
use lib "".path( $Bin, '..', 'lib' );

$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'eg', 'test-app' );
my $app = path( $ENV{MOJO_HOME}, 'myapp.pl' );
require $app;

my $t = Test::Mojo->new;

$t->get_ok( '/yancy/api' )
    ->status_is( 200 )
    ->json_has( '/definitions' )
    ;

$t->get_ok( '/people' )
    ->status_is( 200 )
    ->text_is( 'tbody tr:nth-child(1) td:nth-child(1) a', 'Philip J. Fry' )
    ->element_exists( 'a[href=/people/1]', 'people details link exists' )
    ;

$t->get_ok( '/people/1' )
    ->status_is( 200 )
    ->text_is( 'h1', 'Philip J. Fry' )
    ->element_exists( 'a[href=/people/1/edit]', 'edit link exists' )
    ->element_exists( 'a[href=/people]', 'back to list link' )
    ;

$t->get_ok( '/people/1/edit' )
    ->status_is( 200 )
    ->text_is( 'h1', 'Philip J. Fry' )
    ->element_exists(
        'form[method=POST]',
        'form with POST exists',
    )
    ->element_exists_not(
        '[name=id]',
        'id field does not exist',
    )
    ->element_exists(
        '[name=name][value="Philip J. Fry"]',
        'name field exists with correct value',
    )
    ->element_exists(
        '[name=email][value="fry@example.com"]',
        'email field exists with correct value',
    )
    ->element_exists(
        '[name=age][value=32]',
        'email field exists with correct value',
    )
    ->element_exists( '[name=phone]', 'phone field exists' )
    ->element_exists( '[name=gender]', 'gender field exists' )
    ->element_exists( '[name=contact]', 'contact field exists' )
    ->element_exists( '[name=birthday]', 'birthday field exists' )
    ->element_exists( 'button', 'submit button exists' )
    ->element_exists( 'a[href=/people/1]', 'back to details link' )
    ;

done_testing;
