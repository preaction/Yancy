package Yancy::Plugin::Editor;
our $VERSION = '1.089';
# ABSTRACT: Yancy content editor, admin, and management application

=head1 SYNOPSIS

    use Mojolicious::Lite;

    # The default editor at /yancy
    plugin 'Yancy::Plugin::Editor' => {
        model => $model,
        storage => Yancy::Storage->new(app->home->child('storage')),
    };

=head1 DESCRIPTION

This plugin contains the Yancy editor application which allows editing
the data in a L<Yancy::Model>.

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 model

The L<Yancy::Model> to use for this editor.

=head2 storage

The L<Yancy::Storage> to use for this editor.

=head2 users

The L<Yancy::User> model to check logins with. Only logged-in users can use
the editor. Requests to the editor API and storage from anyone else get a
C<401> response, and the editor page redirects to the first
L<auth|Yancy::User/auths> registered with the model (or responds with
C<401> if there is none).

Either this or L</allow_anonymous> is required.

=head2 allow_anonymous

Set to true to allow anyone to use the editor without logging in. B<Only use
this for development, or with a L</route> that already requires a login>.

=head2 route

A base route to add the editor to. This allows you to customize the URL
and add your own authentication or authorization. Defaults to C</yancy>.

This can be a string or a L<Mojolicious::Routes::Route> object.

=head2 return_to

The URL to use for the "Back to Application" link. Defaults to C</>.

=head2 title

The title of the page, shown in the title bar and the page header. Defaults to
C<Yancy>.

=head1 SEE ALSO

L<Yancy::Guides::Schema>, L<Mojolicious::Plugin::Yancy>, L<Yancy>

=cut

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Scalar::Util qw( blessed );
use Mojo::JSON qw( to_json );
use Mojo::File qw( path );

sub register($self, $app, $config) {
    $config->{title} //= 'Yancy';
    $config->{return_label} //= 'Back to Application';

    my $model = $config->{model};
    my $storage = $config->{storage};
    my $users = $config->{users};
    if ( !$users && !$config->{allow_anonymous} ) {
      die "Yancy::Plugin::Editor requires a `users` model to check logins, or `allow_anonymous => 1`\n";
    }

    my $route = blessed $config->{route} ? $config->{route} : $app->routes->any( $config->{route} // '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );
    my $base = $route->render({});

    if ( $users ) {
      $route = $route->under( sub ($c) {
        return 1 if $users->current_user( $c );
        my $path = $c->req->url->path->to_string;
        my ( $auth ) = @{ $users->auths };
        if ( !$auth || $path =~ m{^\Q$base\E/(?:api|storage)(?:/|$)} ) {
          $c->render( status => 401, json => { errors => [ { message => 'Login required' } ] } );
          return undef;
        }
        $c->redirect_to( $auth->url_for( $c )->query( return_to => $c->req->url->path_query ) );
        return undef;
      } );
    }

    push @{$app->renderer->paths}, path(__FILE__)->dirname->sibling('Editor', 'templates');
    push @{$app->static->paths}, path(__FILE__)->dirname->sibling('Editor', 'dist');
    push $app->routes->namespaces->@*, 'Yancy::Controller';

    # Routes to edit things in the model
    $route->get( '/api' => { hidden => 1, format => 'json' }, sub($c) {
      $c->render( json => $model->json_schema );
    });
    $route->get( '/api/:schema' => { hidden => 1, controller => 'model', action => 'list', model => $model, format => 'json' });
    $route->post( '/api/:schema' => { hidden => 1, controller => 'model', action => 'set', model => $model, format => 'json' });
    $route->get( '/api/:schema/*id' => { hidden => 1, controller => 'model', action => 'get', model => $model, format => 'json' });
    $route->any( ['POST', 'PUT'] => '/api/:schema/*id' => { hidden => 1, controller => 'model', action => 'set', model => $model, format => 'json' });
    $route->any( ['DELETE'] => '/api/:schema/*id' => { hidden => 1, controller => 'model', action => 'delete', model => $model, format => 'json' });

    # Routes to edit things in the storage
    $route->get( '/storage/*id', { hidden => 1, storage => $storage } )->to( 'storage#get' );
    $route->get( '/storage', { hidden => 1, storage => $storage } )->to( 'storage#list' );
    $route->put( '/storage/*id', { hidden => 1, storage => $storage } )->to( 'storage#put' );
    $route->post( '/storage/*prefix', { hidden => 1, storage => $storage, prefix => '' })->to( 'storage#post' );
    $route->any( ['DELETE'] => '/storage/*id', { hidden => 1, storage => $storage } )->to( 'storage#delete' );

    # Route(s) to view the editor
    $route->get( '/*rest', { rest => '', hidden => 1, base => $base, template => 'yancy/editor' }, sub($c) {
      if (!$c->stash('rest') && !$c->req->url->path->trailing_slash) {
        $c->res->code(308);
        return $c->redirect_to($c->req->url->path->trailing_slash(1));
      }
      $c->render();
    });

    return;
}

1;
