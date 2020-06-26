
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
use Local::Test qw( init_backend load_fixtures );
use Mojolicious;
use Yancy::Util qw( is_type is_format );

BEGIN {
    eval "use Test::Mojo::Role::Selenium 0.16; 1"
        or plan skip_all => 'Test::Mojo::Role::Selenium >= 0.16 required to run this test';
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

my %fixtures = load_fixtures( 'foreign-key-field', 'composite-key', 'markdown' );
my ( $backend_url, $backend, %items ) = init_backend( { %$schema, %fixtures }, %data );

sub init_app {
    my $app = Mojolicious->new;
    $app->log->level( 'debug' )->handle( \*STDERR )
        ->format( sub {
            my ( $time, $level, @lines ) = @_;
            return sprintf '# [%s] %s', $level, join "\n", @lines, "";
        } );
    $app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => { %$schema, %fixtures },
        read_schema => 1,
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
    ->screenshot_directory( $Bin )
    ->setup_or_skip_all;

$t->navigate_ok("/yancy")
    ->status_is(200)
    ->wait_for( '#sidebar-schema-list li:nth-child(2) a' )
    # Make sure we didn't add anything to the history stack
    ->main::script_result_is( 'return window.history.length', 2, 'only the new window page and current page in history' )
    ->click_ok( '#sidebar-schema-list a[data-schema=people]' )
    ->wait_for( 'table[data-schema=people]' )
    ->main::script_result_is( 'return window.history.length', 3, 'another page in history' )
    ->main::capture( 'people-list' )
    ->click_ok( '#add-item-btn' )
    ->main::capture( 'people-new-item-form' )
    ->send_keys_ok( '#new-item-form [name=name]', 'Scruffy' )
    ->send_keys_ok( '#new-item-form [name=email]', 'janitor@example.com' )
    ->main::capture( 'people-new-item-edited' )
    ->send_keys_ok( undef, \'return' )
    ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
    ->main::close_all_toasts
    ->main::capture( 'people-new-item-added' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(2)', 'Scruffy', 'name is correct' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(3)', 'janitor@example.com', 'email is correct' )
    ->live_text_is( 'tbody tr:nth-child(1) td:nth-child(4)', 'No', 'can contact default is correct' )
    ;

subtest 'x-list-columns template' => sub {
    $t->click_ok( '#sidebar-schema-list a[data-schema=blog]', 'click blog schema' )
      ->wait_for( 'table[data-schema=blog]' )
      ->live_text_like(
        'tbody tr:nth-child(1) td:nth-child(2)', qr{^\s*I <b><3</b> Perl\s*\(/perl/heart\)\s*$},
        'unsafe characters in value are escaped'
      )
      ->main::capture( 'blog-list-view' )
      ->click_ok( '#sidebar-schema-list a[data-schema=people]', 'click people schema' )
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
    $t->click_ok( '#sidebar-schema-list a[data-schema=user]' )
        ->wait_for( 'table[data-schema=user]' )
        ->click_ok( '#add-item-btn' )
        ->wait_for( '#new-item-form [name=avatar]' )
        ->main::capture( 'user-new-item-form' )
        ->send_keys_ok( '#new-item-form [name=username]', 'postaction' )
        ->send_keys_ok( '#new-item-form [name=password]', '123qwe' )
        ->send_keys_ok( '#new-item-form [name=email]', 'doug@example.com' )
        ->send_keys_ok( '#new-item-form [name=avatar]', [ $SHARE->child( 'avatar.jpg' )->realpath->to_string ] )
        ->click_ok( '#new-item-form [name=access] option:nth-child(1)' )
        ->click_ok( '#new-item-form .save-button' )
        ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
        ->main::close_all_toasts
        ->main::capture( 'user-new-item-added' )
        # Re-open the item to see the existing file
        ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
        ->wait_for( '.edit-form' )
        ->main::capture( 'user-edit-item-form' )
        ;
};

subtest 'yes/no fields' => sub {
    $t->click_ok( '#sidebar-schema-list a[data-schema=blog]', 'click blog schema' )
      ->wait_for( 'table[data-schema=blog]' )
      ->click_ok( 'table[data-schema=blog] tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .yes-no' )
      ->live_element_exists( '.edit-form .yes-no :nth-child(2).active', 'Published is "No"' )
      ->click_ok( '.edit-form .yes-no :nth-child(1)', 'click Published: "Yes"' )
      ->main::scroll_to( '.edit-form .save-button' )
      ->click_ok( '.edit-form .save-button' )
      ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
      ->main::close_all_toasts
      ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form .yes-no' )
      ->live_element_exists( '.edit-form .yes-no :nth-child(1).active', 'Published is "Yes"' )
      ->main::scroll_to( '.edit-form .cancel-button' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'foreign key field' => sub {
    $t->main::add_item( address_types => { address_type => 'Home' } )
      ->main::add_item( address_types => { address_type => 'Business' } )
      ->main::add_item( cities => { city_name => 'Chicago', city_state => 'IL' } )
      ->main::add_item( cities => { city_name => 'New York', city_state => 'NY' } )
      ->click_ok( '#sidebar-schema-list a[data-schema=addresses]' )
      ->wait_for( 'table[data-schema=addresses]' )
      ->click_ok( '#add-item-btn' )
      ### Address Type
      # Wait for the foreign key to load display data
      ->wait_for( '#new-item-form [data-name=address_type_id].foreign-key.loaded' )
      ->main::capture( 'address-add-item-form' )
      # Click the button to open the address search dialog
      ->click_ok( '[data-name=address_type_id].foreign-key button' )
      ->wait_for( '[data-name=address_type_id] .dropdown-menu' )
      ->main::capture( 'address-add-select-type-form' )
      # Type in a search string
      ->wait_for( '[data-name=address_type_id] .dropdown-menu input[type=text]' )
      ->send_keys_ok( '[data-name=address_type_id] .dropdown-menu input[type=text]', 'Busi' )
      ->send_keys_ok( undef, \'return' )
      # Wait for search to complete
      ->wait_for( '[data-name=address_type_id] .dropdown-menu .list-group button' )
      ->live_text_like( '[data-name=address_type_id] .dropdown-menu .list-group button:first-child', qr{Business}, 'menu shows search results' )
      # Select the item
      ->click_ok( '[data-name=address_type_id] .dropdown-menu .list-group button:first-child' )
      ->wait_for( '[data-name=address_type_id] .dropdown-menu input[type=text]:hidden' )
      ->main::capture( 'address-add-select-type-done' )
      # Button shows new value
      ->live_text_like( '[data-name=address_type_id] button', qr{Business}, 'button text shows new value' )
      ### City
      # Wait for the foreign key to load display data
      ->wait_for( '#new-item-form [data-name=city_id].foreign-key.loaded' )
      # Click the button to open the search dialog
      ->click_ok( '[data-name=city_id].foreign-key button' )
      ->wait_for( '[data-name=city_id] .dropdown-menu' )
      ->main::capture( 'address-add-select-city-form' )
      # Type in a search string
      ->wait_for( '[data-name=city_id] .dropdown-menu input[type=text]' )
      ->send_keys_ok( '[data-name=city_id] .dropdown-menu input[type=text]', 'Chic' )
      ->send_keys_ok( undef, \'return' )
      # Wait for search to complete
      ->wait_for( '[data-name=city_id] .dropdown-menu .list-group button' )
      ->live_text_like( '[data-name=city_id] .dropdown-menu .list-group button:first-child', qr{Chicago, IL}, 'menu shows search result with template' )
      # Select the item
      ->click_ok( '[data-name=city_id] .dropdown-menu .list-group button:first-child' )
      ->wait_for( '[data-name=city_id] .dropdown-menu input[type=text]:hidden' )
      ->main::capture( 'address-add-select-city-done' )
      # Button shows new value
      ->live_text_like( '[data-name=city_id] button', qr{Chicago, IL}, 'button text shows new value' )
      # Add other required fields
      ->send_keys_ok( '[name=street]', '123 Example Ave' )
      # Submit the form
      ->click_ok( '#new-item-form .save-button' )
      ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
      ->main::close_all_toasts
      ->main::capture( 'address-add-saved' )
      ->click_ok( 'table[data-schema=addresses] tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form [data-name=address_type_id].foreign-key.loaded' )
      ->wait_for( '.edit-form [data-name=city_id].foreign-key.loaded' )
      ->main::capture( 'address-edit-item-form' )
      ->live_text_like( '[data-name=address_type_id]', qr{Business}, 'address type button text shows current value' )
      ->live_text_like( '[data-name=city_id]', qr{Chicago, IL}, 'city button text shows current value' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'composite key fields' => sub {
    $t->main::add_item(
        wiki_pages => {
            wiki_page_id => 1,
            revision_date => '1992-01-01 00:00:00',
            title => 'My Title',
            slug => 'MyTitle',
            content => '# My title',
        }
      )
      ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form [name=revision_date]' )
      ->live_value_is( '.edit-form [name=revision_date]', '1992-01-01T00:00' )
      ->main::scroll_to( '.edit-form .cancel-button' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'markdown fields' => sub {
    $t->main::add_item(
        pages => {
            title => 'My Title',
            slug => 'MyTitle',
            content => '# My Title',
        }
      )
      ->click_ok( 'table tbody tr:nth-child(1) a.edit-button' )
      ->wait_for( '.edit-form [name=title]' )
      ->live_value_is( '.edit-form [name=title]', 'My Title' )
      ->live_value_is( '.edit-form [name=content]', '# My Title' )
      ->live_text_is( '.edit-form .markdown-preview[data-name=content] h1', 'My Title' )
      ->main::scroll_to( '.edit-form .cancel-button' )
      ->click_ok( '.edit-form .cancel-button' )
      ;
};

subtest 'custom menu' => sub {
    $t->click_ok( '#sidebar-collapse ul[data-menu=Plugins] a[data-menu-item="Custom Element"]' )
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

sub script_result_is {
    my ( $t, $script, $value, $description ) = @_;
    $t->tap( sub {
        is $_->driver->execute_script( $script ), $value, $description;
    } );
}

sub script_diag {
    my ( $t, $script ) = @_;
    $t->tap( sub {
        diag explain $t->driver->execute_script( $script );
    } );
}

sub add_item {
    my ( $t, $schema, $item ) = @_;
    $t->click_ok( sprintf '#sidebar-schema-list a[data-schema=%s]', $schema )
        ->wait_for( sprintf 'table[data-schema=%s]', $schema )
        ->click_ok( '#add-item-btn' )
        ->wait_for( '#new-item-form [name]' )
        ->main::capture( $schema . '-new-item-form' )
        ;
    $t->main::fill_item_form( '#new-item-form', $schema, $item );
    $t->main::scroll_to( '#new-item-form .save-button' )
        ->click_ok( '#new-item-form .save-button' )
        ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
        ->main::close_all_toasts
        ->main::capture( $schema . '-new-item-added' )
        ;
}

sub fill_item_form {
    my ( $t, $form, $schema_name, $values ) = @_;
    my $schema = $t->app->yancy->schema( $schema_name );
    for my $field_name ( keys %$values ) {
        my $field_el = sprintf '%s [name=%s]', $form, $field_name;
        my $type = $schema->{properties}{ $field_name }{type} // '';
        my $format = $schema->{properties}{ $field_name }{format} // '';
        my $value = $values->{ $field_name };
        if ( is_type( $type, 'string' ) && is_format( $format, 'filepath' ) ) {
            $t->send_keys_ok( $field_el, [ $value->realpath->to_string ] );
        }
        elsif ( is_type( $type, 'string' ) && is_format( $format, 'date-time' ) ) {
            $t->main::fill_datetime( $field_el, $value );
        }
        elsif ( $schema->{properties}{ $field_name }{enum} ) {
            $t->click_ok( sprintf '%s option[value=%s]', $field_el, $value );
        }
        # XXX: Add foreign key field
        # XXX: Add yes/no field
        elsif ( is_type( $type, 'string' ) && is_format( $format, 'markdown' ) ) {
            $t->send_keys_ok( $field_el, $value );
        }
        else {
            $t->send_keys_ok( $field_el, $value );
        }
    }
}

sub edit_item {
    my ( $t, $schema, $item_id, $update ) = @_;
    $t->click_ok( sprintf '#sidebar-schema-list a[data-schema=%s]', $schema )
        ->wait_for( sprintf 'table[data-schema=%s]', $schema )
        ->click_ok( sprintf 'table[data-schema=%s] tr[data-item-id="%s"]', $schema, $item_id )
        ->wait_for( '.edit-form' )
        ->main::capture( $schema . '-edit-form' )
        ;
    $t->main::fill_item_form( '.edit-form', $schema, $update );
    $t->main::scroll_to( '.edit-form .save-button' )
        ->click_ok( '.edit_form .save-button' )
        ->wait_for( '.toast-header button.close, .alert', 'save toast banner or error' )
        ->main::close_all_toasts
        ->main::capture( $schema . '-item-edited' )
        ;
}

sub fill_datetime {
    my ( $t, $field, $dt ) = @_;
    my ( $y, $m, $d, $h, $n ) = $dt =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/;
    $t->tap( sub {
        $_->send_keys_ok( $field, [ split( //, $m ), \'tab' ] );
        $_->send_keys_ok( $field, [ split( //, $d ), \'tab' ] );
        $_->send_keys_ok( $field, [ $y, \'tab' ] );
        $_->send_keys_ok( $field, [ split( //, $h ), \'tab' ] );
        $_->send_keys_ok( $field, [ split( //, $n ), \'tab' ] );
        $_->send_keys_ok( $field, [ 'AM' ] );
    } );
}

sub close_all_toasts {
    my ( $t, $selector ) = @_;
    $t->tap( sub {
        $_->driver->execute_async_script(q{
            var callback = arguments[0],
                toasts = $('.toast').filter( ':visible' ),
                total = toasts.length,
                hidden = 0;
            toasts.each( function ( i, el ) {
                $( el ).on( 'hidden.bs.toast', function ( el ) {
                    hidden++;
                    if ( hidden >= total ) {
                        callback();
                    }
                } );
                $( el ).toast( 'hide' );
            } );
        });
    } );
}

