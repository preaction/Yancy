
=head1 DESCRIPTION

This tests the included Yancy VueJS components, which the editor is built on.

To run this test, you must install Test::Mojo::Role::Selenium and
Selenium::Chrome. Then you must set the C<TEST_SELENIUM> environment
variable to C<1>.

Additionally, setting C<YANCY_SELENIUM_CAPTURE=1> in the environment
will add screenshots to the C<t/selenium> directory. Each screenshot
begins with a counter so you can see the application state as the test
runs.

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


my %data = (
    employees => [
        {
            name => 'Philip J. Fry',
            email => 'fry@example.com',
            department => 'Delivery Boy',
        },
        {
            name => 'Turanga Leela',
            email => 'eye@example.com',
            department => 'Pilot',
        },
        {
            name => 'Bender B. Rodriguez',
            email => 'benderisgreat@example.com',
            department => 'Cook',
        },
        {
            name => 'Professor Hubert Farnsworth',
            email => 'ceo@example.com',
            department => 'Mad Scientist',
        },
        {
            name => 'John A. Zoidberg',
            email => 'crab@example.com',
            department => 'Doctor',
        },
        {
            name => 'Hermes Conrad',
            email => 'hermes.conrad@example.com',
            department => 'Filing',
        },
    ],
);
my %fixtures = load_fixtures( 'basic' );
my ( $backend_url, $backend, %items ) = init_backend( \%fixtures, %data );

sub init_app {
    my $app = Mojolicious->new;
    $app->log->level( 'debug' )->handle( \*STDERR )
        ->format( sub {
            my ( $time, $level, @lines ) = @_;
            return sprintf '# [%s] %s', $level, join "\n", @lines, "";
        } );
    $app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => \%fixtures,
        read_schema => 1,
    } );

    push @{ $app->renderer->classes }, 'main';
    $app->routes->get( '/table' )->to(
        controller => 'Yancy',
        action => 'list',
        schema => 'employees',
        template => 'test_table',
    );

    return $app;
}

my $app = init_app;
my $t = Test::Mojo->with_roles("+Selenium")->new( $app )
    ->screenshot_directory( $Bin )
    ->setup_or_skip_all;

subtest table => sub {
    $t->navigate_ok( '/table' )
        ->wait_for( '#test-table tbody tr' )
        ->live_text_like(
            '#test-table thead th:nth-child(1)',
            qr{name},
            'column title defaults to field name',
        )
        ->live_text_like(
            '#test-table thead th:nth-child(2)',
            qr{E-mail},
            'column title defined in object',
        )
        ->live_text_like(
            '#test-table thead th:nth-child(3)',
            qr{Job},
            'column title defined in object',
        )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(1)',
            qr{Fry},
            'first employee name is correct',
        )
        ->live_element_exists(
            '#test-table tbody tr:nth-child(1) td:nth-child(2) a[href="mailto:fry@example.com"]',
            'first employee email is a mailto: link',
        )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(2) a',
            qr{fry\@example\.com},
            'first employee email is correct',
        )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(3)',
            qr{Delivery Boy},
            'first employee department is correct',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(1)',
            'first page button exists',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(1).disabled',
            'first page button is disabled on page 1',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(2)',
            'prev page button exists',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(2).disabled',
            'prev page button disabled on page 1',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(3).active',
            'page 1 button in paginator is active',
        )
        ->live_text_like(
            '#test-table .pagination .page-item:nth-child(3) a',
            qr{1},
            'paginator text to go to page 1 is correct',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(4).active',
            'page 2 button in paginator is not active',
        )
        ->live_text_like(
            '#test-table .pagination .page-item:nth-child(4) a',
            qr{2},
            'paginator text to go to page 2 is correct',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(5)',
            'next page button exists',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(5).disabled',
            'next page button not disabled',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(6)',
            'last page button exists',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(6).disabled',
            'last page button not disabled',
        )
        ->click_ok(
            '#test-table thead th:nth-child(3)',
            'click Department column header to sort',
        )
        ->wait_for( '#test-table tbody tr' )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(1)',
            qr{Bender},
            'employees are sorted by Department, ascending',
        )
        ->click_ok(
            '#test-table thead th:nth-child(3)',
            'click Department column header to sort',
        )
        ->wait_for( '#test-table tbody tr' )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(1)',
            qr{Leela},
            'employees are sorted by Department, descending',
        )
        ->click_ok(
            '#test-table .pagination li:last-child a',
            'click "Last" pagination button',
        )
        ->wait_for( '#test-table tbody tr' )
        ->live_text_like(
            '#test-table tbody tr:nth-child(1) td:nth-child(1)',
            qr{John A. Zoidberg},
            'next page of employees, sorted by Department, descending',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(1)',
            'first page button exists',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(1).disabled',
            'first page button not disabled on page 2',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(2)',
            'prev page button exists',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(2).disabled',
            'prev page button not disabled on page 2',
        )
        ->live_text_like(
            '#test-table .pagination .page-item:nth-child(3) a',
            qr{1},
            'paginator text to go to page 1 is correct',
        )
        ->live_element_exists_not(
            '#test-table .pagination .page-item:nth-child(3).active',
            'page 1 button in paginator is not active',
        )
        ->live_text_like(
            '#test-table .pagination .page-item:nth-child(4) a',
            qr{2},
            'paginator text to go to page 2 is correct',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(4).active',
            'page 2 button in paginator is active',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(5)',
            'next page button exists',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(5).disabled',
            'next page button disabled on page 2',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(6)',
            'last page button exists',
        )
        ->live_element_exists(
            '#test-table .pagination .page-item:nth-child(6).disabled',
            'last page button disabled on page 2',
        )
        #->wait_for( 900 )
};



done_testing;

__DATA__
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        %= javascript '/yancy/jquery.js'
        %= javascript '/yancy/vue.js'
        %= javascript '/yancy/bootstrap.js'
        %= stylesheet '/yancy/font-awesome/css/font-awesome.css'
        %= stylesheet '/yancy/bootstrap.css'
    </head>
    <body>
        %= content
    </body>
</html>

@@ test_table.html.ep
% layout 'default';
%= include 'yancy/component/table'

<main id="app">
    <yancy-table id="test-table"
        limit="3"
        :columns="[ 'name', { title: 'E-mail', template: '<a href=&quot;mailto:{email}&quot;>{email}</a>' }, { title: 'Job', field: 'department' } ]"
    ></yancy-table>
</main>

<script>
    var vm = new Vue({ el: '#app' });
</script>
