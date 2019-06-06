
=head1 DESCRIPTION

This tests the Yancy editor application JavaScript.

To run this test, you must install Test::Mojo::Role::Selenium and
Selenium::Chrome. Then you must set the C<TEST_SELENIUM> environment
variable to C<1>.

Additionally, setting C<YANCY_SELENIUM_CAPTURE=1> in the environment
will add screenshots to the C<t/selenium> directory. Each screenshot
begins with a counter so you can see the application state as the test
runs.

=head2 NOTES

The editor item form uses focus/blur events to update the data, so
using C<submit_ok> does not work correctly. Using
C<send_keys_ok( undef, \'return' )> works, and also tests that the
submit event is properly handled.

=cut

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Mojolicious;

BEGIN {
    eval { require Test::Mojo::Role::Selenium; 1 }
        or plan skip_all => 'Test::Mojo::Role::Selenium required to run this test';
};

$ENV{MOJO_SELENIUM_DRIVER}   ||= 'Selenium::Chrome';
$ENV{YANCY_SELENIUM_CAPTURE} ||= 0; # Disable screenshots by default

my $schema = \%Yancy::Backend::Test::SCHEMA;
my ( $backend_url, $backend, %items ) = init_backend( $schema );
my $app = Mojolicious->new;
$app->log->level( 'debug' )->handle( \*STDERR )
    ->format( sub {
        my ( $time, $level, @lines ) = @_;
        return sprintf '# [%s] %s', $level, join "\n", @lines, "";
    } );
$app->plugin( 'Yancy', {
    backend => $backend_url,
    read_schema => 1,
} );

my $t = Test::Mojo->with_roles("+Selenium")->new( $app )->setup_or_skip_all;
$t->navigate_ok("/yancy")
    ->screenshot_directory( $Bin )
    ->status_is(200)
    ->wait_for( '#sidebar-schema-list' )
    ->click_ok( '#sidebar-schema-list li:nth-child(2) a' )
    ->wait_for( 'table' )
    ->main::capture( 'after-people-clicked' )
    ->click_ok( '#add-item-btn' )
    ->main::capture( 'after-new-item-clicked' )
    ->send_keys_ok( '#new-item-form [name=name]', 'Doug Bell' )
    ->send_keys_ok( '#new-item-form [name=email]', 'doug@example.com' )
    ->send_keys_ok( undef, \'return' )
    ->wait_for( '.toast, .alert', 'save toast banner or error' )
    ->main::capture( 'new-item-added' )
    ->live_text_like( 'tbody tr:nth-child(1) td:nth-child(2)', qr{^\d+$}, 'id is a number' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(3)', 'Doug Bell', 'name is correct' )
    ;

#=head2 capture
#
#   $t->main::capture( $name )
#
# Capture a screenshow and increment a counter so we can see the
# screenshots in order to help debugging.
#
# This sub only runs if the YANCY_SELENIUM_CAPTURE environment variable
# is set.
sub capture {
    my ( $t, $name ) = @_;
    return $t unless $ENV{YANCY_SELENIUM_CAPTURE};
    state $i = 1;
    $t->capture_screenshot( sprintf '%03d-%s', $i, $name );
    $i++;
    return $t;
}

done_testing;
