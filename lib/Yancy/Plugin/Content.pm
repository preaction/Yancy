package Yancy::Plugin::Content;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::JSON qw( decode_json encode_json true false );
use Mojolicious::Routes;

=head1 DESCRIPTION

Load the L<Yancy::Content> model into your Mojolicious application and set up appropriate dispatching.

=cut

has model => sub { die 'model is required' };
has log => sub { die 'log is required' };

sub register( $self, $app, @args ) {
    $self->log( $app->log );

    my %args = scalar @args == 1 && ref $args[0] eq 'HASH' ? $args[0]->%* : @args;
    my $model = Yancy::Content->new(%args);
    $self->model($model);

    $app->hook( before_server_start => sub ( $server, $app ) {
        $self->init($app);
    });

    $app->hook( before_dispatch => sub ($c) {
        # See if we have an override for this route and render that instead
        $app->log->debug('building routes for database pages');
        my $dbr = Mojolicious::Routes->new(
            map { $_ => $app->routes->$_ } qw(base_classes conditions namespaces shortcuts types),
        );
        my $res = $model->schema('pages')->list({ -not_bool => 'in_app' });
        for my $page ( sort { length $b->{pattern} <=> length $a->{pattern} } $res->{items}->@* ) {
            $app->log->debug('adding route for database page: ' . $page->{pattern});
            my $method = lc $page->{method};
            $dbr->$method($page->{pattern})->to(
                cb => sub ( $c ) {
                    $c->render();
                },
                decode_json($page->{params} // '{}')->%*,
                title => $page->{title},
                template => $page->{template},
            );
        }
        $app->log->debug('attempting dispatch to database page');
        my $ok = $dbr->dispatch($c);
        $app->log->debug('dispatch to database page ' . ($ok ? 'success' : 'failed'));
    });

    $app->helper( content => sub { $self } );
    $app->helper( block => sub ($c, $name, $attrs, $content=sub {}) {
        # Look up the block in the database
        my $res = $self->model->schema('blocks')->list({
            path => $c->match->path_for->{path},
            name => $name,
        });
        if ( $res->{items}->@* ) {
            $content = sub { $res->{items}[0]{content} };
        }
        return $c->tag('y-block', %$attrs, $content);
    } );

    $app->helper( item => sub ($c, $item, $content) {
        return $c->tag('y-item', itemid => encode_json($item->id), $content);
    });
    $app->helper( prop => sub ($c, $item, $prop_name) {
        return $c->tag('y-prop', name => $prop_name, sub { $item->data->{$prop_name} });
    });

    $app->helper( widget => sub ($c, $schema, $method, $args, $content) {
        # Execute the model method to get the template data
        # XXX: This is the wrong model!
        my @res = $model->schema($schema)->$method(@$args);
        return $c->tag('y-widget', schema => $schema, method => $method, args => encode_json($args), $content->(@res));
    } );
}

sub init($self, $app) {
    # Initialize the schema with the application's data
    # First, reconcile the pages in the database with the routes in the
    # app.
    my %app_routes = map { $_->{name} => $_ } $self->_walk_route($app->routes);
    my %db_routes = map { $_->{name} => $_ } @{$self->model->backend->list( pages => {})->{items} // []};
    for my $name ( keys %app_routes ) {
        my $app_route = $app_routes{$name};
        my $db_route = $db_routes{$name};
        if ( $db_route ) {
            delete $db_routes{ $name };
            next unless $db_route->{in_app};
            $self->model->backend->set(pages => $name => $app_route);
        }
        else {
            $self->model->backend->create(pages => $app_route);
        }
    }
    # Remaining database routes should be deleted
    $self->model->backend->delete( pages => $_->{name} ) for values %db_routes;
}

sub _walk_route($self, $parent, $prefix='') {
  # Flatten the app routes tree using the $prefix
  my @routes;
  for my $r ( $parent->children->@* ) {
    if ($r->pattern->defaults->{hidden}) {
      next;
    }
    my $pattern = $prefix . ($r->pattern->unparsed // '/');
    $self->log->debug('got pattern for route ' . $pattern . ' ' . $r->name);
    if ($r->is_endpoint && !$r->is_websocket) {
        push @routes,
          {
            name => $r->name,
            method => $r->methods->[0],
            pattern => $pattern,
            title => $r->pattern->defaults->{title},
            template => $r->pattern->defaults->{template},
            in_app => true,
          },
          ;
    }
    push @routes, $self->_walk_route($r, $pattern);
  }
  return @routes;
}

1;
