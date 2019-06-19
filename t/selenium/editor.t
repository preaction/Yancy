
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

$ENV{MOJO_HOME}              = path( $Bin, '..', 'share' );
$ENV{MOJO_SELENIUM_DRIVER}   ||= 'Selenium::Chrome';
$ENV{YANCY_SELENIUM_CAPTURE} ||= 0; # Disable screenshots by default

my $schema = \%Yancy::Backend::Test::SCHEMA;
$schema->{blog} = {
    %{ $schema->{blog} },
    title => 'Blog Posts',
    'x-list-columns' => [
        { title => 'Post', template => '{title} ({slug})' },
    ],
};
$schema->{people} = {
    %{ $schema->{people} },
    title => 'People',
    description => 'These are the people we all know',
    'x-list-columns' => [ 'name', 'email', 'contact' ],
    'x-view-url' => '/people',
    'x-view-item-url' => '/people/{id}',
};
$schema->{user} = {
    %{ $schema->{user} },
    title => 'Users',
    'x-id-field' => 'username',
    'x-list-columns' => [ 'username', 'email' ],
};

my %titles = (
    people => {
        id => 'ID',
        name => 'Name',
        email => 'E-mail',
        age => 'Age',
        phone => 'Phone Number',
        contact => 'Can Contact?',
    },
);
for my $schema_name ( keys %titles ) {
    for my $prop_name ( keys %{ $titles{ $schema_name } } ) {
        $schema->{ $schema_name }{ properties }{ $prop_name }{ title }
            = $titles{ $schema_name }{ $prop_name };
    }
}

my %data = (
    people => [
        {
            name => 'Philip J. Fry',
            email => 'fry@example.com',
            age => 32,
        },
        {
            name => 'Turanga Leela',
            email => 'leela@example.com',
            age => 34,
        },
        {
            name => 'Bender B. Rodriguez',
            email => 'bender@example.com',
            age => 5,
        },
        {
            name => 'Dr. John A. Zoidberg',
            email => 'zoidberg@example.com',
            age => 58,
        },
        {
            name => 'Hubert J. Farnsworth',
            email => 'ceo@example.com',
            age => 163,
        },
        {
            name => 'Hermes Conrad',
            email => 'coo@example.com',
            age => 47,
        },
        {
            name => 'Amy Wong',
            email => 'amy@example.com',
            age => 23,
        },
    ],
    blog => [
        { # Test XML escaping in x-list-columns templates
            title => 'I <b><3</b> Perl',
            slug => '/perl/heart',
        },
    ],
);

my ( $backend_url, $backend, %items ) = init_backend( $schema, %data );

sub init_app {
    my $app = Mojolicious->new;
    $app->log->level( 'debug' )->handle( \*STDERR )
        ->format( sub {
            my ( $time, $level, @lines ) = @_;
            return sprintf '# [%s] %s', $level, join "\n", @lines, "";
        } );
    $app->plugin( 'Yancy', {
        backend => $backend_url,
        read_schema => 1,
        schema => $schema,
    } );
    return $app;
}

my $app = init_app;
my $t = Test::Mojo->with_roles("+Selenium")->new( $app )->setup_or_skip_all;
$t->navigate_ok("/yancy")
    # Test normal size and create screenshots for the docs site
    ->set_window_size( [ 800, 600 ] )
    ->screenshot_directory( $Bin )
    ->status_is(200)
    ->wait_for( '#sidebar-schema-list' )
    ->click_ok( '#sidebar-schema-list li:nth-child(2) a' )
    ->wait_for( 'table' )
    ->main::capture( 'after-people-clicked' )
    ->click_ok( '#add-item-btn' )
    ->main::capture( 'after-new-item-clicked' )
    ->send_keys_ok( '#new-item-form [name=name]', 'Scruffy' )
    ->send_keys_ok( '#new-item-form [name=email]', 'janitor@example.com' )
    ->main::capture( 'new-item-edited' )
    ->send_keys_ok( undef, \'return' )
    ->wait_for( '.toast, .alert', 'save toast banner or error' )
    ->main::capture( 'new-item-added' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(2)', 'Scruffy', 'name is correct' )
    ->click_ok( '.toast-header button.close', 'dismiss toast banner' )
    ;

subtest 'x-list-columns template' => sub {
    $t->click_ok( '#sidebar-schema-list li:nth-child(1) a', 'click blog schema' )
      ->wait_for( 'table' )
      ->live_text_like(
        'tbody tr:nth-child(1) td:nth-child(2)', qr{I <b><3</b> Perl},
        'unsafe characters in value are escaped'
      )
      ->main::capture( 'blog-list-view' )
      ;
};

subtest 'custom menu' => sub {
    my $app = init_app;

    # Add custom menu items
    $app->yancy->editor->include( 'plugin/editor/custom_element' );
    $app->yancy->editor->menu(
        Plugins => 'Custom Element',
        {
            component => 'custom-element',
        },
    );

    my $t = Test::Mojo->with_roles("+Selenium")->new( $app )->setup_or_skip_all;
    $t->navigate_ok("/yancy")
        # Test normal size and create screenshots for the docs site
        ->set_window_size( [ 800, 600 ] )
        ->screenshot_directory( $Bin )
        ->status_is(200)
        # Custom plugin menu
        ->click_ok( '#sidebar-collapse h6:nth-of-type(1) + ul li:nth-child(1) a' )
        ->wait_for( '#custom-element', 'custom element is shown' )
        ->main::capture( 'custom-element-clicked' )
        ;
};

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
