#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Mojo::SQLite;
use lib 'lib';

### Bootstrap
# First, set up the database
my $db = Mojo::SQLite->new('sqlite::temp:');
$db->migrations->from_data->migrate;

# Next, load the model
use Yancy::Backend::Sqlite;
my $backend = Yancy::Backend::Sqlite->new($db);
# XXX: read_schema should always happen now...
$backend->schema( $backend->read_schema );
use Yancy::Content;
my $model = Yancy::Content->new(backend => $backend);
unshift app->plugins->namespaces->@*, 'Yancy::Plugin';
app->plugin( 'Content' => backend => $backend );

# Then, load the editor
# TODO: This is Yancy::Plugin::Editor
push @{app->static->paths}, 'lib/Yancy/Editor/dist';
get '/yancy' => { hidden => 1, template => 'yancy/editor' }, sub ($c) {
  if (!$c->req->url->path->trailing_slash) {
    $c->res->code(308);
    return $c->redirect_to($c->req->url->path->trailing_slash(1));
  }
  $c->render();
};
push app->routes->namespaces->@*, 'Yancy::Controller';
get '/yancy/api/:schema' => { hidden => 1, controller => 'yancy', action => 'list', model => $model, format => 'json' };
post '/yancy/api/:schema' => { hidden => 1, controller => 'yancy', action => 'set', model => $model, format => 'json' };
get '/yancy/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'get', model => $model, format => 'json' };
put '/yancy/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'set', model => $model, format => 'json' };
any ['DELETE'] => '/yancy/api/:schema/*id' => { hidden => 1, controller => 'yancy', action => 'delete', model => $model, format => 'json' };

# TODO: 'Mojolicious::Plugin::Yancy' is combination of above things

# Finally, create the web app's routes
plugin AutoReload =>;
get '/' => sub ($c) {
  $c->app->log->info('DEBUG');
  $c->render(template => 'index');
}, 'index';
get '/multi' => sub ($c) {
  $c->app->log->info('DEBUG');
  $c->render(template => 'multi-blocks');
}, 'multi-blocks';
get '/artist/:slug' => sub ($c) {
  $c->app->log->info('DEBUG');
  $c->render(template => 'index');
}, 'artist-page';

app->start;
__DATA__
@@ migrations
-- 1 up
CREATE TABLE pages (
  page_id INTEGER AUTO_INCREMENT PRIMARY KEY,
  name STRING NOT NULL,
  method STRING NOT NULL,
  pattern STRING NOT NULL,
  title STRING,
  template STRING,
  params STRING NOT NULL DEFAULT '{}',
  in_app BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (name),
  UNIQUE (pattern)
);
CREATE TABLE blocks (
  block_id INTEGER AUTO_INCREMENT PRIMARY KEY,
  path STRING NOT NULL,
  name STRING NOT NULL,
  content STRING,
  UNIQUE (path, name)
);


-- 1 down
DROP TABLE blocks;
DROP TABLE pages;

@@ yancy/editor.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>Yancy Editor</title>
    %= stylesheet '/editor/Yancy.css'
    %= javascript type => 'module', defer => '', src => '/editor/index.js'
  </head>
  <body>
    <div id="app"></div>
  </body>
</html>

@@ index.html.ep
% layout 'default';
%= block landing => {}, begin
This is the default landing page content.
% end

@@ multi-blocks.html.ep
% layout 'default';
%= block hero => {}, begin
This is the default hero content.
% end
<div style="display: flex">
%= block left => {}, begin
This is the default left content.
% end
%= block right => {}, begin
This is the default right content.
% end
</div>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <style>
      body {
        background: #251903;
        color: #f9ed91;
        font-family: sans-serif;
        margin: 0 auto;
      }
      a:link {
        color: #ddd;
      }
      a:visited {
        color: #ccc;
      }
      a:active, a:hover {
        color: #eee;
      }

      address { white-space: pre-wrap; }

      .sr-only {
        width: 0;
        overflow: hidden;
        visibility: hidden;
        display: none;
      }
      .index-top {
        display: flex;
        flex: 1 0 33%;
        align-items: center;
        justify-content: center;
      }
      .index-top > * {
        width: 33%;
        padding: 0 2em;
      }
      .index-top .logo-large {
        order: 2;
      }
      .index-top .hours {
        order: 3;
        margin: 0 auto;
      }
      .index-top address {
        order: 1;
        text-align: right;
      }

      .index-bottom {
        display: flex;
        flex: 1 0 33%;
        align-items: flex-start;
        justify-content: center;
      }
      .index-bottom > * {
        max-width: 33%;
        padding: 0 1em;
      }
      .index-bottom h1 {
        text-align: center;
      }
      .index-bottom .art-scroll {
        width: 25%;
      }
      .art-scroll > * {
        display: block;
        margin: 0 auto;
      }

      .logo-large {
        text-align: center;
      }
      .logo-large img {
        max-width: 100%;
      }

      .hours td {
        text-align: center;
      }

      .read-more {
        text-align: right;
      }
    </style>
  </head>
  <body>
    <%= content %>
  </body>
</html>
