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

=head2 route

A base route to add the editor to. This allows you to customize the URL
and add authentication or authorization. Defaults to C</yancy> with no
authentication.

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

    my $route = blessed $config->{route} ? $config->{route} : $app->routes->any( $config->{route} // '/yancy' );
    $route->to( return_to => $config->{return_to} // '/' );

    push @{$app->renderer->paths}, path(__FILE__)->dirname->sibling('Editor', 'templates');
    push @{$app->static->paths}, path(__FILE__)->dirname->sibling('Editor', 'dist');
    push $app->routes->namespaces->@*, 'Yancy::Controller';

    # Route to view the editor
    $route->get( '/', { hidden => 1, template => 'yancy/editor' }, sub($c) {
      if (!$c->req->url->path->trailing_slash) {
        $c->res->code(308);
        return $c->redirect_to($c->req->url->path->trailing_slash(1));
      }
      $c->render();
    });

    # Routes to edit things in the model
    $route->get( '/api' => { hidden => 1, format => 'json' }, sub($c) {
      $c->render( json => $model->json_schema );
    });
    $route->get( '/api/:schema' => { hidden => 1, controller => 'yancy', action => 'list', model => $model, format => 'json' });
    $route->post( '/api/:schema' => { hidden => 1, controller => 'yancy', action => 'set', model => $model, format => 'json' });
    $route->get( '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'get', model => $model, format => 'json' });
    $route->any( ['POST', 'PUT'] => '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'set', model => $model, format => 'json' });
    $route->any( ['DELETE'] => '/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'delete', model => $model, format => 'json' });

    # Routes to edit things in the storage
    $route->get( '/storage/*id', { hidden => 1, storage => $storage }, 'storage#get' );
    $route->get( '/storage', { hidden => 1, storage => $storage }, 'storage#list' );
    $route->put( '/storage/*id', { hidden => 1, storage => $storage }, 'storage#put' );
    $route->post( '/storage/*prefix', { hidden => 1, storage => $storage, prefix => '' }, 'storage#post' );
    $route->any( ['DELETE'] => '/storage/*id', { hidden => 1, storage => $storage }, 'storage#delete' );

    return;
}

1;
