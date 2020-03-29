
=head1 DESCRIPTION

This tests an example application in the C<eg/todo-app> directory to
make sure it still works with the new version of Yancy.

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
use DateTime;

$ENV{MOJO_HOME} = path( $Bin, '..', '..', 'eg', 'todo-app' );
my $app = path( $ENV{MOJO_HOME}, 'myapp.pl' );
eval { require $app };
if ( $@ && $@ =~ /Perl v5\.\d+\.\d+ required--this is only v\d+\.\d+\.\d+/ ) {
    plan skip_all => 'Could not load t/examples/todo-app.t: ' . $@;
}

my $t = Test::Mojo->new;
$t->app->yancy->create( users => {
    username => 'test',
    password => '123qwe',
} );

$t->get_ok( '/' )
    ->status_is( 401 )
    ;
$t->get_ok( '/yancy/auth' )
    ->element_exists( 'input[name=username]', 'login form username field exists' )
    ->element_exists( 'input[name=password]', 'login form password field exists' )
    ;

$t->post_ok( '/yancy/auth/password', form => { username => 'test', password => '123qwe', return_to => '/' } )
    ->status_is( 303 )
    ->header_is( Location => '/' )
    ;

$t->get_ok( '/yancy/api' )
    ->status_is( 200 )
    ->json_has( '/definitions' )
    ;

my $today = DateTime->today( time_zone => 'US/Central' );
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
    ->status_is( 302 )
    ->header_is( Location => '/' . $today->ymd )
    ;
$t->get_ok( '/' . $today->ymd )
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

my $dom = $t->tx->res->dom;
if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[0]{id} . ']' ),
    'form to complete daily item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Do the dishes\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}
else {
    diag $t->tx->res->dom;
}

if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[1]{id} . ']' ),
    'form to complete weekly item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Write a blog\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}

if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[2]{id} . ']' ),
    'form to complete monthly item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Clean the floors\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}

$t->post_ok( '/log/' . $log_items[0]{id}, form => { complete => 1 } )
    ->status_is( 302 )
    ->header_is( Location => '/' . $today->ymd )
    ;

my $log_item = $t->app->yancy->get( todo_log => $log_items[0]{id} );
is $log_item->{complete}, $today->ymd, 'todo log complete is updated';

$t->get_ok( '/' . $today->ymd )
    ->status_is( 200 )
    ->text_is( 'h1', $today->ymd )
    ;

$dom = $t->tx->res->dom;
if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[0]{id} . ']' ),
    'form to complete daily item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Do the dishes\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Undo\s*$},
        'button text correct for complete item';
}

if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[1]{id} . ']' ),
    'form to complete weekly item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Write a blog\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}

if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[2]{id} . ']' ),
    'form to complete monthly item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Clean the floors\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}

my $tomorrow = $today->clone->add( days => 1 );
$t->get_ok( '/' . $tomorrow->ymd )
    ->status_is( 200 )
    ->text_is( 'h1', $tomorrow->ymd )
    ;

@log_items = $t->app->yancy->list( 'todo_log' => {
    start_date => $tomorrow->ymd,
    end_date => $tomorrow->ymd,
} );
is scalar @log_items, 1, 'a new daily log item created';

$dom = $t->tx->res->dom;
if ( ok my $elem = $dom->at( 'form[action=/log/' . $log_items[0]{id} . ']' ),
    'form to complete new daily item exists'
) {
    like $elem->at( 'span' )->text, qr{^\s*Do the dishes\s*$},
        'todo item text correct';
    like $elem->at( 'button' )->text, qr{^\s*Complete\s*$},
        'button text correct for incomplete item';
}

done_testing;
