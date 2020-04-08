
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
use Mojo::File qw( path tempdir );
use lib "".path( $Bin, '..', 'lib' );
use Local::Test qw( init_backend );
use Mojolicious;

BEGIN {
    eval { require Test::Mojo::Role::Selenium; 1 }
        or plan skip_all => 'Test::Mojo::Role::Selenium required to run this test';
};

my $SHARE = path( $Bin, '..', 'share' );
$ENV{MOJO_HOME}              = $SHARE;
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
    'x-list-columns' => [
        {
            field => 'name',
            title => 'Name',
            template => '<a href="/people/{id}">{name}</a>',
        },
        'email', 'contact',
    ],
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
    user => [
        {
            username => 'preaction',
            email => 'doug@example.com',
            password => '123qwe',
        },
        {
            username => 'inara',
            email => 'gatita@example.com',
            password => '123qwe',
        },
    ],
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
            markdown => '# I Heart Perl',
            html => '<h1>I Heart Perl</h1>',
            username => 'preaction',
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
        schema => $schema,
        read_schema => 1,
        schema => $schema,
    } );

    # Add custom menu items
    $app->yancy->editor->include( 'plugin/editor/custom_element' );
    $app->yancy->editor->menu(
        Plugins => 'Custom Element',
        {
            component => 'custom-element',
        },
    );

    my $upload_dir = tempdir;
    push @{ $app->static->paths }, $upload_dir;
    $upload_dir->child( 'uploads' )->make_path;
    $app->yancy->plugin( File => {
        file_root => $upload_dir->child( 'uploads' ),
    } );
    return $app;
}

my $app = init_app;
my $t = Test::Mojo->with_roles("+Selenium")->new( $app )
    ->driver_args({
        desired_capabilities => {
            # This causes no window to appear. It took me forever to
            # figure this out ... but it no longer works in Chrome 77
            # chromeOptions => {
            #     args => [ 'headless', 'window-size=1024,768' ],
            # },
        },
    })
    ->screenshot_directory( $Bin )
    ->setup_or_skip_all;

$t->navigate_ok("/yancy")
    ->status_is(200)
    ->wait_for( '#sidebar-schema-list li:nth-child(2) a' )
    ->click_ok( '#sidebar-schema-list li:nth-child(2) a' )
    ->wait_for( 'table[data-schema=people]' )
    ->main::capture( 'people-list' )
    ->click_ok( '#add-item-btn' )
    ->main::capture( 'people-new-item-form' )
    ->send_keys_ok( '#new-item-form [name=name]', 'Scruffy' )
    ->send_keys_ok( '#new-item-form [name=email]', 'janitor@example.com' )
    ->main::capture( 'people-new-item-edited' )
    ->send_keys_ok( undef, \'return' )
    ->wait_for( '.toast, .alert', 'save toast banner or error' )
    ->main::capture( 'people-new-item-added' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(2)', 'Scruffy', 'name is correct' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(3)', 'janitor@example.com', 'email is correct' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(4)', 'No', 'can contact default is correct' )
    ->click_ok( '.toast-header button.close', 'dismiss toast banner' )
    ;

subtest 'x-list-columns template' => sub {
    $t->click_ok( '#sidebar-schema-list li:nth-child(1) a', 'click blog schema' )
      ->wait_for( 'table[data-schema=blog]' )
      ->live_text_like(
        'tbody tr:nth-child(1) td:nth-child(2)', qr{^\s*I <b><3</b> Perl\s*\(/perl/heart\)\s*$},
        'unsafe characters in value are escaped'
      )
      ->main::capture( 'blog-list-view' )
      ->click_ok( '#sidebar-schema-list li:nth-child(2) a', 'click people schema' )
      ->wait_for( 'table' )
      ->live_element_exists(
        'tbody tr:nth-child(1) td:nth-child(2) a[href$="/people/' . $items{people}[0]{id} . '"]',
        'link is to correct url',
      )
      ->or( sub { diag "Philip J. Fry ($items{people}[0]{id}) link href: " . shift->driver->find_element_by_link_text( 'Philip J. Fry' )->get_attribute( 'href' ) } )
      ->live_text_like(
        'tbody tr:nth-child(1) td:nth-child(2)', qr{^\s*Philip J[.] Fry\s*$},
        'x-list-columns template contains correct text'
      )
      ->main::capture( 'people-list-view' )
      # Filter the people list
      ->click_ok( 'button.new-filter', 'new filter' )
      ->wait_for( '#filter-form', 'wait for the filter to be added' )
      ->send_keys_ok( '#filter-form input', 'Fry', 'add filter text' )
      ->click_ok( '#filter-form select', 'click filter select list' )
      ->click_ok( '#filter-form select option:nth-child(1)', 'click first field (name) in select list' )
      ->click_ok( '#filter-form .add-filter', 'add the new filter' )
      ->wait_for( '.filters div:nth-of-type(1)', 'wait for the filter to be added' )
      ->live_element_count_is( 'tbody tr', 2, 'filter leaves one row' )
      ->live_text_like(
        'tbody tr:nth-child(1) td:nth-child(2)', qr{^\s*Philip J[.] Fry\s*$},
        'only row contains correct person'
      )
      ->main::capture( 'people-filter' )
      ;
};

subtest 'upload file' => sub {
    # User schema has avatar field
    $t->click_ok( '#sidebar-schema-list li:nth-child(3) a' )
        ->wait_for( 'table' )
        ->click_ok( '#add-item-btn' )
        ->wait_for( '#new-item-form [name=avatar]' )
        ->main::capture( 'user-new-item-form' )
        ->send_keys_ok( '#new-item-form [name=username]', 'postaction' )
        ->send_keys_ok( '#new-item-form [name=password]', '123qwe' )
        ->send_keys_ok( '#new-item-form [name=email]', 'doug@example.com' )
        ->send_keys_ok( '#new-item-form [name=avatar]', [ $SHARE->child( 'avatar.jpg' )->realpath->to_string ] )
        ->click_ok( '#new-item-form [name=access] option:nth-child(1)' )
        ->click_ok( '#new-item-form .save-button' )
        ->wait_for( '.toast, .alert', 'save toast banner or error' )
        ->main::capture( 'user-new-item-added' )
        ->click_ok( '.toast-header button.close', 'dismiss toast banner' )
        # Re-open the item to see the existing file
        ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
        ->wait_for( '.edit-form' )
        ->main::capture( 'user-edit-item-form' )
        ;
};

subtest 'yes/no fields' => sub {
    $t->click_ok( '#sidebar-schema-list li:nth-child(1) a', 'click blog schema' )
      ->wait_for( 'table[data-schema=blog]' )
      ->click_ok( 'table[data-schema=blog] tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .yes-no' )
      ->live_element_exists( '.edit-form .yes-no :nth-child(2).active', 'Published is "No"' )
      ->click_ok( '.edit-form .yes-no :nth-child(1)', 'click Published: "Yes"' )
      ->main::scroll_to( '.edit-form .save-button' )
      ->click_ok( '.edit-form .save-button' )
      ->wait_for( '.toast, .alert', 'save toast banner or error' )
      ->click_ok( '.toast-header button.close', 'dismiss toast banner' )
      ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .yes-no' )
      ->live_element_exists( '.edit-form .yes-no :nth-child(1).active', 'Published is "Yes"' )
      ->main::scroll_to( '.edit-form .cancel-button' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'x-foreign-key' => sub {
    $t->click_ok( '#sidebar-schema-list li:nth-child(1) a', 'click blog schema' )
      ->wait_for( 'table[data-schema=blog]' )
      ->click_ok( 'table[data-schema=blog] tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .foreign-key.loaded' )
      ->main::capture( 'blog-edit-item-form' )
      ->live_text_like( '[name=username]', qr{preaction}, 'username button text shows user name' )
      ->click_ok( '[name=username]' ) # Click the button to open the dialog box
      ->wait_for( '.dropdown-menu' )
      ->main::capture( 'blog-select-user-dialog' )
      # XXX Error while executing command: unknown command: unknown
      # command: Cannot call non W3C standard command while in W3C mode
      #->active_element_is( '.dropdown-menu input[type=text]', 'search box is focused' )
      # Type and submit a search
      ->send_keys_ok( '.dropdown-menu input[type=text]', 'ina' )
      ->send_keys_ok( undef, \'return' )
      ->wait_for( '.dropdown-menu .list-group button' )
      ->live_text_like( '.dropdown-menu .list-group button:first-child', qr{inara}, 'menu shows search results' )
      # ... Click the other user in the list (inara)
      ->click_ok( '.dropdown-menu .list-group button:first-child' )
      ->wait_for( '.dropdown-menu input[type=text]:hidden' )
      ->main::capture( 'blog-select-user-done' )
      ->live_text_like( '[name=username]', qr{inara}, 'username button text shows new user name' )
      ->click_ok( '.edit-form .save-button' )
      ->wait_for( '.toast, .alert', 'save toast banner or error' )
      ->main::capture( 'blog-select-user-saved' )
      ->click_ok( 'table[data-schema=blog] tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .foreign-key.loaded' )
      ->main::capture( 'blog-edit-item-form' )
      ->live_text_like( '[name=username]', qr{inara}, 'username button text shows new user name' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'custom menu' => sub {
    $t->click_ok( '#sidebar-collapse h6:nth-of-type(1) + ul li:nth-child(1) a' )
        ->wait_for( '#custom-element', 'custom element is shown' )
        ->main::capture( 'custom-element-clicked' )
        ;
};

done_testing;

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

#=head2 scroll_to
#
#   $t->main::scroll_to( $selector )
#
# Scroll so the given element is in the middle of the viewport
sub scroll_to {
    my ( $t, $selector ) = @_;
    $t->tap( sub {
        $_->driver->execute_script(
            'document.querySelector(arguments[0]).scrollIntoView({ block: "center" })',
            $selector,
        )
    } );
}

