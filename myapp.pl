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
#unshift app->plugins->namespaces->@*, 'Yancy::Plugin';
app->plugin( 'Yancy::Plugin::Content' => backend => $backend );

use Yancy::Storage;
my $storage = Yancy::Storage->new( app->home->child('public/storage')->make_path );

# Then, load the editor
plugin 'Yancy::Plugin::Editor', {
  model => $model,
  storage => $storage,
};

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
get '/fixture/*fixture_path' => { fixture_path => 'index' }, sub ($c) {
  $c->render(template => $c->param('fixture_path'));
}, 'fixtures';

app->start;
__DATA__
@@ migrations
-- 1 up
CREATE TABLE pages (
  page_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
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
  block_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  path STRING NOT NULL,
  name STRING NOT NULL,
  content STRING,
  UNIQUE (path, name)
);


-- 1 down
DROP TABLE blocks;
DROP TABLE pages;

@@ index.html.ep
% layout 'default';
%= block landing => {}, begin
This is just sitting here because...
<p>This is the default landing page content.</p>
This is just sitting here because...
<h1>This is an H1</h1>
This is just sitting here because...
% end
<p>This is outside the y-block</p>

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

@@ restrict-editable.html.ep
% layout 'default';
%= block schedule => { editable => 'td' } => begin
<table>
  <caption>Gallery Hours</caption>
  <thead>
    <tr>
      <th class="sr-only"></th>
      <th aria-label="Sunday">Su</th>
      <th aria-label="Monday">Mo</th>
      <th aria-label="Tuesday">Tu</th>
      <th aria-label="Wednesday">We</th>
      <th aria-label="Thursday">Th</th>
      <th aria-label="Friday">Fr</th>
      <th aria-label="Saturday">Sa</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th class="sr-only">Open</th>
      <td>10</td>
      <td>-</td>
      <td>4</td>
      <td>2</td>
      <td>4</td>
      <td>12</td>
      <td>10</td>
    </tr>
    <tr>
      <th class="sr-only">Close</th>
      <td>2</td>
      <td>-</td>
      <td>8</td>
      <td>6</td>
      <td>9</td>
      <td>8</td>
      <td>10</td>
    </tr>
  </tbody>
</table>
% end

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
    <script src="/iframe/index.js"></script>
    <script>
      Yancy.allowOrigins = [new RegExp("http://localhost:\\d+"), new RegExp("http://127\\.0\\.0\\.1:\\d+")];
    </script>
  </body>
</html>
