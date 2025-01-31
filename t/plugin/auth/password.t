
=head1 DESCRIPTION

This tests the auth password module, which allows for password-based
logins.

=head1 SEE ALSO

L<Yancy::Plugin::Auth::Password>, L<Yancy::Plugin::Auth>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );
use Digest;

my ( $backend_url, $backend, %items ) = init_backend(
    \%Local::Test::SCHEMA,
    user => [
        {
            username => 'doug',
            email => 'doug@example.com',
            password => Digest->new( 'SHA-1' )->add( '123qwe' )->b64digest . '$SHA-1',
        },
        {
            username => 'joel',
            email => 'joel@example.com',
            password => Digest->new( 'SHA-256' )->add( '456rty' )->b64digest . '$SHA-256',
        },
    ],
);

my $T = make_app(allow_register => 1);

subtest 'current_user' => sub {
    subtest 'success' => sub {
        my $c = $T->app->build_controller;
        $c->session->{yancy}{auth}{password} = $items{user}[0]{username};
        my %expect_user = %{ $items{user}[0] };
        delete $expect_user{ password };
        is_deeply $c->yancy->auth->current_user, \%expect_user,
            'current_user is correct';
    };

    subtest 'failure' => sub {
        my $c = $T->app->build_controller;
        is $c->yancy->auth->current_user, undef,
            'current_user is undef for invalid session';
    };

};

subtest 'login_form' => sub {
    my $c = $T->app->build_controller;
    ok my $html = $c->yancy->auth->login_form, 'login form is returned';
    my $dom = Mojo::DOM->new( $html );
    ok $dom->at( 'input[name=username]' ), 'username field exists';
    ok $dom->at( 'input[name=password]' ), 'password field exists';
};

subtest 'protect routes' => sub {
    my $t = make_app();

    my $cb = $t->app->yancy->auth->require_user;
    is ref $cb, 'CODE', 'require_user returns a CODE ref';
    my $under = $t->app->routes->under( '', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Foo" );
        $c->render( data => 'Ok' );
    } );

    subtest 'unauthorized' => sub {
        subtest 'html' => sub {
            $t->get_ok( '/' )->status_is( 401 )
              ->content_like( qr{You are not authorized} )
              ->element_exists( 'form[action=/yancy/auth/password]', 'login form exists' )
              ->or( sub { diag shift->tx->res->dom->find( 'form' )->each } )
              ->element_exists( 'input[name=return_to][value=/]', 'login form has correct return_to' )
              ->or( sub { diag shift->tx->res->dom->find( 'input' )->each } )
              ;
        };
        subtest 'json' => sub {
            $t->get_ok( '/', { Accept => 'application/json' } )
              ->status_is( 401 )
              ->json_like( '/errors/0/message', qr{You are not authorized} )
              ->or( sub { diag shift->tx->res->body } );
        };
    };

    subtest 'user can login' => sub {
        $t->get_ok( '/yancy/auth/password' => { Referer => '/' } )
          ->status_is( 200 )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password]', 'form exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username]',
              'username input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]',
              'password input exists',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ->element_exists_not(
              '.login-error',
              'login error alert box not shown',
          )
          ;

        $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123', return_to => '/' } )
          ->status_is( 400 )
          ->header_isnt( Location => '/yancy' )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username][value=doug]',
              'username input exists with value pre-filled',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]:not([value])',
              'password input exists without value',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ->text_like(
              '.login-error', qr{\s*Login failed: User or password incorrect!\s*},
              'login error alert box shown',
          )
          ;

        $t->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', } )
          ->status_is( 303 )
          ->header_is( location => '/' );
    };

    subtest 'authorized' => sub {
        $t->get_ok( '/' )->status_is( 200 )->content_is( 'Ok' );
    };
};

subtest 'errors' => sub {
    subtest 'user not found' => sub {
        $T->post_ok( '/yancy/auth/password', form => { username => 'NOT FOUND', password => '123', return_to => '/' } )
          ->status_is( 400 )
          ->header_isnt( Location => '/yancy' )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=username][value=NOT FOUND]',
              'username input exists with value pre-filled',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=password]:not([value])',
              'password input exists without value',
          )
          ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/]',
              'return to field exists with correct value',
          )
          ->text_like(
              '.login-error', qr{\s*Login failed: User or password incorrect!\s*},
              'login error alert box shown',
          )
          ;
    };

    subtest 'return_to security -- must return to the same site' => sub {
        $T->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', return_to => 'http://example.com' } )
          ->status_is( 500 )
          ->post_ok( '/yancy/auth/password', form => { username => 'doug', password => '123qwe', return_to => '//example.com' } )
          ->status_is( 500 )
    };
};

subtest 'logout' => sub {
    $T->get_ok( '/yancy/auth/password/logout', { Referer => '/yancy' } )
      ->status_is( 303 )
      ->header_is( location => '/yancy' )
      ->get_ok( '/yancy/auth/password/logout' )
      ->status_is( 303 )
      ->header_is( location => '/' )
      ->get_ok( '/yancy/auth/password/logout?redirect_to=/', { Referer => '/yancy' } )
      ->status_is( 303 )
      ->header_is( location => '/' )
      ;
};

subtest 'test login form respects flash value' => sub {
    my $t = make_app();

    $t->ua->max_redirects(1);

    my $cb = sub {
        my ( $c ) = @_;

        # if there's no logged in user, redirect to the login form
        # with return_to set in the flash so it survives the redirect to be read by 
        # the login form handler

        if ($t->app->yancy->auth->current_user) {
            return 1;
        }
        else {
           $c->flash({ return_to => '/other_page' });
           $c->redirect_to('/yancy/auth/password');
           return undef;
        }
    };

    my $under = $t->app->routes->under( '', $cb );
    $under->get( '/' )->to( cb => sub {
        my ( $c ) = @_;
        $c->app->log->info( "Foo" );
        $c->render( data => 'Ok' );
    } );
    
    # after redirect should have a status of 200 and login form with return_to value to '/other_page'
    $t->get_ok( '/' )->status_is( 200 )
        ->element_exists(
              'form[method=POST][action=/yancy/auth/password] input[name=return_to][value=/other_page]',
              'return to field exists with correct value after redirect with flashed url',
        );
};

subtest 'register' => sub {
    $T->get_ok( '/yancy/auth/password/register' )
      ->status_is( 200 )
      ->or( sub { diag shift->tx->res->body } )
      ->element_exists( 'input[name=username]', 'username field exists' )
      ->element_exists( 'input[name=password]', 'password field exists' )
      ->element_exists( 'input[name=password-verify]', 'password-verify field exists' )
      ->element_exists( 'input[name=email]', 'email field exists' )
      ->or( sub { diag shift->tx->res->dom->at( 'form' ) } )
      ->element_exists( 'form button', 'submit button exists' )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'foo',
              password => 'bar',
              'password-verify' => 'baz',
              email => 'doug@example.com',
          }
      )
      ->status_is( 400 )
      ->content_like( qr{Passwords do not match} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'doug',
              password => 'haha',
              'password-verify' => 'haha',
              email => 'doug@example.com',
          }
      )
      ->status_is( 400 )
      ->content_like( qr{User already exists} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'mickey',
              password => 'metacpan',
              'password-verify' => 'metacpan',
          }
      )
      ->status_is( 400 )
      ->or( sub { diag shift->tx->res->body } )
      ->content_like( qr{Invalid data} )
      ->post_ok( '/yancy/auth/password/register',
          form => {
              username => 'mickey',
              password => 'metacpan',
              'password-verify' => 'metacpan',
              email => 'mickey@example.com',
          }
      )
      ->status_is( 302 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_is( location => '/yancy/auth/password' )
      ->get_ok( '/yancy/auth/password' )
      ->content_like( qr{User created\. Please log in} )
      ->post_ok( '/yancy/auth/password',
          form => {
              username => 'mickey',
              password => 'metacpan',
              return_to => '/',
          }
      )
      ->status_is( 303 )
      ->or( sub { diag shift->tx->res->body } )
      ->header_is( location => '/' );
      ;
};

subtest 'login and change password digest' => sub {
    $T->post_ok( '/yancy/auth/password', form => { username => 'joel', password => '456rty', } )
      ->status_is( 303 )
      ->header_is( location => '/' );
    my $new_user = $backend->get( user => $items{user}[1]{username} );
    my $digest = Digest->new( 'SHA-1' )->add( '456rty' )->b64digest;
    is $new_user->{password}, join( '$', $digest, 'SHA-1' ),
        'user password is updated to new default config';
};

subtest 'regressions' => sub {
    subtest 'no known registerable fields (Github #69)' => sub {
        my $t = Test::Mojo->new( 'Mojolicious' );
        $t->app->plugin( 'Yancy', {
            backend => $backend_url,
            schema => {
                user => {
                    'x-id-field' => 'username',
                    # No required fields here
                    properties => {
                        username => { type => 'string' },
                        password => { type => 'string' },
                    },
                },
            },
        } );
        eval {
            $t->app->yancy->plugin( 'Auth::Password', {
                schema => 'user',
                username_field => 'username',
                password_field => 'password',
                password_digest => { type => 'SHA-1' },
                # No register_fields here
                # No allow_register either
            } );
        };
        ok !$@, 'can load Auth::Password plugin' or diag $@;

    };

};

subtest bcrypt_module => sub {
    my $digest = Digest->new( BcryptYancy => cost => 4 )    #
      ->add('123qwe')->b64digest;
    my $digest2 = Digest->new( BcryptYancy => settings => $digest )    #
      ->add('123qwe')->b64digest;
    is $digest, $digest2, 'digests match';
};

subtest bcrypt => sub {
    my $old_pw       = "456rty";
    my $old_pw_entry = $backend->get( user => "joel" )->{password};
    my $t            = make_app(
        password_digest => { type => 'BcryptYancy', cost => 4 },
        allow_register  => 1,
    );
    $t->post_ok( '/yancy/auth/password' => form =>
          { username => 'joel', password => $old_pw } )->status_is(303)
      ->header_is( location => '/', "login with SHA-1 pw works" );
    my $new_pw_entry = $backend->get( user => "joel" )->{password};
    isnt $new_pw_entry, $old_pw_entry, 'password is updated';
    my ($hash) = split /\$/, $new_pw_entry;
    my $digest = Digest->new( BcryptYancy => settings => $hash )    #
      ->add($old_pw)->b64digest;
    is $hash, $digest, 'user password is updated to new default config';

    $t->post_ok( "/yancy/auth/password" => form =>
          { username => 'joel', password => $old_pw } )->status_is(303)
      ->header_is( location => '/', "login with bcrypt pw works" )    #
      ->get_ok('/yancy/auth/password/logout')->status_is(303)
      ->header_is( location => '/' )                                  #
      ->post_ok(
        "/yancy/auth/password/register" => form => {
            username          => 'bcrypt',
            password          => 'password',
            'password-verify' => 'password',
            email             => 'bcrypt@example.com',
        }
      )                                                               #
      ->status_is(302)->or( sub { diag shift->tx->res->body } )       #
      ->header_is( location => '/yancy/auth/password', "register works" )
      ->get_ok('/yancy/auth/password')
      ->content_like(qr{User created\. Please log in})
      ->post_ok( "/yancy/auth/password" => form =>
          { username => 'bcrypt', password => 'password', return_to => '/' } )
      ->status_is(303)->or( sub { diag shift->tx->res->body } )
      ->header_is( location => '/', "login with bcrypt pw works" );

    like $backend->get( user => "bcrypt" )->{password}, qr/BcryptYancy/,
      "new password correctly uses BcryptYancy";
};

done_testing;

sub make_app {
    my (%pw_options) = @_;
    my $t = Test::Mojo->new( 'Mojolicious' );
    $t->app->plugin( 'Yancy', {
        backend => $backend_url,
        schema => \%Local::Test::SCHEMA,
    } );
    $t->app->yancy->plugin( 'Auth::Password', {
        schema => 'user',
        username_field => 'username',
        password_field => 'password',
        password_digest => { type => 'SHA-1' },
        %pw_options,
    } );
    return $t;
}