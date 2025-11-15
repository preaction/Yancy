
use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw( true false );
use Mojolicious;
use Mojo::Server;
use Yancy::Content;
use Yancy::Backend::Memory;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );

sub schema_integer($order, %attrs) {
    return {
        type => 'integer',
        'x-order' => $order,
        %attrs,
    }
}

sub schema_boolean($order, %attrs) {
    return {
        type => 'boolean',
        'x-order' => $order,
        %attrs,
    }
}

sub schema_string($order, %attrs) {
    return {
        type => 'string',
        'x-order' => $order,
        %attrs,
    }
}

sub schema_autoinc($order = 1, %attrs) {
    return schema_integer($order,
        readOnly => true,
        %attrs,
    );
}

sub schema_child_of($order, $ref, %attrs) {
    # child_of is _required_
    return {
        type => 'integer',
        'x-foreign-key' => $ref,
        %attrs,
    }
}

sub build_backend() {
    my $backend = Yancy::Backend::Memory->new(
        schema => {
            pages => {
                required => [qw( route title )],
                'x-id-field' => 'name',
                properties => {
                    page_id => schema_autoinc(1),
                    name => schema_string(2),
                    method => schema_string(3),
                    pattern => schema_string(4),
                    title => schema_string(5),
                    template => schema_string(6),
                    params => schema_string(7),
                    # If true, this is an app route and should be updated on
                    # startup.
                    in_app => schema_boolean(8, 'x-hidden' => true),
                },
            },
            blocks => {
                required => [qw( path name )],
                'x-id-field' => 'block_id',
                properties => {
                    block_id => schema_autoinc(1),
                    path => schema_string(2),
                    name => schema_string(3),
                    content => schema_string(4),
                },
            },
            widgets => {
                required => [qw( model method params template )],
                'x-id-field' => 'widget_id',
                properties => {
                    widget_id => schema_autoinc(1),
                    model => schema_string(2),
                    method => schema_string(3),
                    args => schema_string(4),
                    template => schema_string(5),
                },
            },
            templates => {
                required => [qw( path content )],
                'x-id-field' => 'path',
                properties => {
                    template_id => schema_autoinc(1),
                    path => schema_string(2),
                    content => schema_string(3),
                },
            },
        }
    );
    return $backend;
}

sub build_app($backend) {
    my $app = Mojolicious->new;
    unshift $app->plugins->namespaces->@*, 'Yancy::Plugin';
    $app->plugin( 'Content' => backend => $backend );
    return Test::Mojo->new( $app );
}

subtest 'pages' => sub {
    my $backend = build_backend();
    my $t = build_app($backend);
    my $app = $t->app;
    my $route_pattern = '/*slug';
    my $route_name = 'default_name';
    my $route_title = 'Default title';
    my $route_template = 'default';
    my $route_method = 'get';
    my $route = $app->routes->$route_method($route_pattern)->to(
        cb => sub ( $c ) { $c->render(my_content => 'default') },
        title => $route_title,
        template => $route_template,
    )->name( $route_name );

    # Get the "before_server_start" hook to run.
    $app->server(Mojo::Server->new);

    my $model = $app->content->model;
    my $schema = $model->schema('pages');

    subtest 'app routes are included' => sub {
        my $res = $schema->list;
        is scalar $res->{items}->@*, 1, 'empty data table finds route from app';
        my $item = $res->{items}->[0];
        is lc $item->{method}, lc $route_method;
        is lc $item->{name}, $route_name;
        is lc $item->{pattern}, $route_pattern;
        is $item->{title}, $route_title;
        is lc $item->{template}, $route_template;
        ok $item->{in_app}, 'page is flagged as in_app';

    };

    subtest 'can override app routes' => sub {
        my $override = {
           title => 'New title',
           template => 'new_template',
        };
        $schema->set( $route_name => $override );

        my $got = $schema->get($route_name);
        is $got->{title}, $override->{title};
        is $got->{template}, $override->{template};
        ok !$got->{in_app}, 'page is flagged as overridden';

        # method, name, pattern may not be changed
        is lc $got->{method}, lc $route_method;
        is lc $got->{name}, $route_name;
        is lc $got->{pattern}, $route_pattern;

        subtest 'overridden route is not clobbered on startup' => sub {
            my $model = Yancy::Content->new( app => $app, backend => $backend );
            my $got = $schema->get($route_name);
            is $got->{title}, $override->{title};
            is $got->{template}, $override->{template};
            ok !$got->{in_app}, 'page is flagged as overridden';
        };

        subtest 'overridden route can be dispatched' => sub {
            $t->get_ok('/slug')->status_is(200)->content_is("overridden\n");
        };
    };

    subtest 'route "/" is included' => sub {
        local %Yancy::Backend::Memory::DATA = ();
        my $backend = build_backend();
        my $t = build_app($backend);
        my $app = $t->app;
        my $route_pattern = '/';
        my $route = $app->routes->$route_method($route_pattern)->to(
            cb => sub ( $c ) { $c->render(my_content => 'default') },
            title => $route_title,
            template => $route_template,
        )->name( $route_name );
        # Get the "before_server_start" hook to run.
        $app->server(Mojo::Server->new);

        my $model = $app->content->model;
        my $schema = $model->schema('pages');

        my $res = $schema->list;
        is scalar $res->{items}->@*, 1, 'found route "/"';
        if (my $item = $res->{items}->[0]) {
            is lc $item->{method}, lc $route_method;
            is lc $item->{name}, $route_name;
            is lc $item->{pattern}, $route_pattern;
            is $item->{title}, $route_title;
            is lc $item->{template}, $route_template;
            ok $item->{in_app}, 'page is flagged as in_app';
        }
    };

    subtest 'websocket not included' => sub {
        local %Yancy::Backend::Memory::DATA = ();
        my $backend = build_backend();
        my $t = build_app($backend);
        my $app = $t->app;
        my $route_method = 'websocket';
        my $route = $app->routes->$route_method($route_pattern)->to(
            cb => sub ( $c ) { $c->render(my_content => 'default') },
            title => $route_title,
            template => $route_template,
        )->name( $route_name );
        # Get the "before_server_start" hook to run.
        $app->server(Mojo::Server->new);

        my $model = $app->content->model;
        my $schema = $model->schema('pages');

        my $res = $schema->list;
        is scalar $res->{items}->@*, 0, 'websocket route not found';
    };

    subtest 'hidden => 1 not included' => sub {
        local %Yancy::Backend::Memory::DATA = ();
        my $backend = build_backend();
        my $t = build_app($backend);
        my $app = $t->app;
        my $route = $app->routes->$route_method($route_pattern)->to(
            cb => sub ( $c ) { $c->render(my_content => 'default') },
            title => $route_title,
            template => $route_template,
            hidden => 1,
        )->name( $route_name );
        # Get the "before_server_start" hook to run.
        $app->server(Mojo::Server->new);

        my $model = $app->content->model;
        my $schema = $model->schema('pages');

        my $res = $schema->list;
        is scalar $res->{items}->@*, 0, 'hidden => 1 route not found';
    };

    subtest 'under is walked' => sub {
        local %Yancy::Backend::Memory::DATA = ();
        my $backend = build_backend();
        my $t = build_app($backend);
        my $app = $t->app;
        my $route = $app->routes->under('/foo', sub { 1 });
        my $subroute = $route->get('/bar')->to(
            cb => sub ( $c ) { $c->render(my_content => 'default') },
            title => $route_title,
            template => $route_template,
        )->name( $route_name );
        # Get the "before_server_start" hook to run.
        $app->server(Mojo::Server->new);

        my $model = $app->content->model;
        my $schema = $model->schema('pages');

        my $res = $schema->list;
        is scalar $res->{items}->@*, 1, 'found route inside under';
        if (my $item = $res->{items}->[0]) {
            is lc $item->{method}, lc $route_method;
            is lc $item->{name}, $route_name;
            is lc $item->{pattern}, '/foo/bar';
            is $item->{title}, $route_title;
            is lc $item->{template}, $route_template;
            ok $item->{in_app}, 'page is flagged as in_app';
        }
    };
};

subtest 'blocks' => sub {
    my $backend = build_backend();
    my $t = build_app($backend);
    my $app = $t->app;

    $app->routes->get('/*slug')->to( cb => sub ($c) { $c->render('blocks') } );

    # Get the "before_server_start" hook to run.
    $app->server(Mojo::Server->new);

    my $model = $app->content->model;
    my $schema = $model->schema('blocks');

    subtest 'block helper default content' => sub {
        $t->get_ok('/index')->status_is(200)->content_like(qr{\s*<y-block>\s*Default block content\s*</y-block>\s*});
    };

    subtest 'block content can be overridden' => sub {
        $schema->create({
            path => '/index',
            name => 'block_name',
            content => 'Overridden block content',
        });
        $t->get_ok('/index')->status_is(200)->content_is('<y-block>Overridden block content</y-block>');
    };
};

subtest 'widgets' => sub {
    my $backend = build_backend();
    $backend->schema->{blogs} = {
        'x-id-field' => 'blog_id',
        properties => {
            blog_id => schema_integer(1),
            title => schema_string(2),
            content => schema_string(3),
        },
    };
    my $t = build_app($backend);
    my $app = $t->app;

    $app->routes->get('/blog')->to( cb => sub ($c) { $c->render('widgets') } );

    # Get the "before_server_start" hook to run.
    $app->server(Mojo::Server->new);

    my $model = $app->content->model;
    $model->schema('blogs')->create({
        blog_id => 1,
        title => 'blogs',
        content => 'content',
    });

    subtest 'widget helper' => sub {
        $t->get_ok('/blog')->status_is(200);
        $t->attr_is('y-widget', schema => 'blogs');
        $t->attr_is('y-widget', method => 'list');
        $t->attr_is('y-widget', args => '[]');
        $t->attr_is('y-item', itemid => 1);
        $t->attr_is('y-prop', name => 'title');
        $t->text_is('y-prop[name=title]', 'blogs');
    };
};

done_testing;
__END__

subtest 'templates' => sub {
    subtest 'app templates are included' => sub {
    };

    subtest 'can override app template' => sub {
    };
};

done_testing;

__DATA__
@@ default.html.ep
default

@@ new_template.html.ep
overridden

@@ blocks.html.ep
%= block block_name => { }, begin
Default block content
% end

@@ widgets.html.ep
%= widget blogs => list => [], begin
    % my $items = $_[0]->{items};
    % for my $item ( @$items ) {
        %= item $item, begin
            %= prop $item, 'title'
        % end
    % }
% end
