
=head1 DESCRIPTION

This tests an example application in the C<eg/todo-app> directory to
make sure it still works with the new version of Yancy.

These tests require a Postgres running on the local machine. These tests
will destroy a database named C<myapp> in the Postgress running.

=head1 SEE ALSO

C<eg/todo-app>

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
use Mojo::Pg;
use DateTime;

system dropdb => 'myapp', '--if-exists';
system createdb => 'myapp';

$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'eg', 'todo-app' );
my $app = path( $ENV{MOJO_HOME}, 'myapp.pl' );
require $app;

my $t = Test::Mojo->new;

$t->get_ok( '/yancy/api' )
    ->status_is( 200 )
    ->json_has( '/definitions' )
    ;

my $today = DateTime->today;
$t->app->yancy->create( todo_item => {
    title => 'Do the dishes',
    period => 'day',
    interval => 1,
    start_date => $today->ymd,
} );
$t->app->yancy->create( todo_item => {
    title => 'Write a blog',
    period => 'week',
    interval => 1,
    start_date => $today->ymd,
} );
$t->app->yancy->create( todo_item => {
    title => 'Clean the floors',
    period => 'month',
    interval => 1,
    start_date => $today->ymd,
} );

$t->get_ok( '/' )
    ->status_is( 200 )
    ->text_is( 'h1', $today->ymd )
    ->element_exists(
        'a[href=/' . $today->clone->add( days => -1 )->ymd . ']',
        'prev link exists'
    )
    ->element_exists(
        'a[href=/' . $today->clone->add( days => 1 )->ymd . ']',
        'next link exists'
    )
    ;

my @log_items = $t->app->yancy->list( 'todo_log' );
is scalar @log_items, 3, '3 log items created';

$t->element_exists(
        'li:nth-child(1) form[action=/log/' . $log_items[0]{id} . ']',
        'form to complete daily item exists',
    )
    ->text_like( 'li:nth-child(1) span', qr{^\s*Do the dishes\s*$} )
    ->text_like( 'li:nth-child(1) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(2) form[action=/log/' . $log_items[1]{id} . ']',
        'form to complete weekly item exists',
    )
    ->text_like( 'li:nth-child(2) span', qr{^\s*Write a blog\s*$} )
    ->text_like( 'li:nth-child(2) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(3) form[action=/log/' . $log_items[2]{id} . ']',
        'form to complete monthly item exists',
    )
    ->text_like( 'li:nth-child(3) span', qr{^\s*Clean the floors\s*$} )
    ->text_like( 'li:nth-child(3) button', qr{^\s*Complete\s*$} )
    ;

$t->post_ok( '/log/' . $log_items[0]{id}, form => { complete => 1 } )
    ->status_is( 302 )
    ->header_is( Location => '/' . $today->ymd )
    ;

my $log_item = $t->app->yancy->get( todo_log => $log_items[0]{id} );
is $log_item->{complete}, $today->ymd, 'todo log complete is updated';

$t->get_ok( '/' )
    ->status_is( 200 )
    ->text_is( 'h1', $today->ymd )

    ->element_exists(
        'li:nth-child(1) form[action=/log/' . $log_items[1]{id} . ']',
        'form to complete weekly item exists',
    )
    ->text_like( 'li:nth-child(1) span', qr{^\s*Write a blog\s*$} )
    ->text_like( 'li:nth-child(1) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(2) form[action=/log/' . $log_items[2]{id} . ']',
        'form to complete monthly item exists',
    )
    ->text_like( 'li:nth-child(2) span', qr{^\s*Clean the floors\s*$} )
    ->text_like( 'li:nth-child(2) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(3) form[action=/log/' . $log_items[0]{id} . ']',
        'form to undo daily item exists',
    )
    ->text_like( 'li:nth-child(3) span', qr{^\s*Do the dishes\s*$} )
    ->text_like( 'li:nth-child(3) button', qr{^\s*Undo\s*$} )
    ;

my $tomorrow = $today->clone->add( days => 1 );
$t->get_ok( '/' . $tomorrow->ymd )
    ->status_is( 200 )
    ->text_is( 'h1', $tomorrow->ymd )
    ;

@log_items = $t->app->yancy->list( 'todo_log' );
is scalar @log_items, 4, 'a new daily log item created';

$t->element_exists(
        'li:nth-child(1) form[action=/log/' . $log_items[0]{id} . ']',
        'form to complete weekly item exists',
    )
    ->text_like( 'li:nth-child(1) span', qr{^\s*Write a blog\s*$} )
    ->text_like( 'li:nth-child(1) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(2) form[action=/log/' . $log_items[1]{id} . ']',
        'form to complete monthly item exists',
    )
    ->text_like( 'li:nth-child(2) span', qr{^\s*Clean the floors\s*$} )
    ->text_like( 'li:nth-child(2) button', qr{^\s*Complete\s*$} )

    ->element_exists(
        'li:nth-child(3) form[action=/log/' . $log_items[3]{id} . ']',
        'form to complete daily item exists',
    )
    ->text_like( 'li:nth-child(3) span', qr{^\s*Do the dishes\s*$} )
    ->text_like( 'li:nth-child(3) button', qr{^\s*Complete\s*$} )
    ;

done_testing;
