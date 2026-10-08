#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite -signatures;

# These are annotations that will be added to the JSON Schema.
my %model_schema = (
);

### Mojolicious::Plugin::Yancy
# XXX: This should be all handled by Mojolicious::Plugin::Yancy 
use Mojo::SQLite;
my $db = Mojo::SQLite->new('sqlite:myapp.db');

use Yancy::Backend::Sqlite;
my $backend = Yancy::Backend::Sqlite->new($db);

use Yancy::Model;
my $db_model = Yancy::Model->new(
  backend => $backend,
  schema => \%model_schema,
);

use Yancy::Content;
my $content = Yancy::Content->new(backend => $backend);
plugin 'Yancy::Plugin::Content' => backend => $backend;

use Yancy::Storage;
my $storage = Yancy::Storage->new( app->home->child('public/storage')->make_path );

use Yancy::Model::Layer;
my $model = Yancy::Model::Layer->new( $db_model, $content );
helper model => sub($c, $schema=undef) { $schema ? $model->schema($schema) : $model };
helper 'yancy.model' => sub($c, $schema=undef) { $schema ? $model->schema($schema) : $model };

# Then, load the editor
plugin 'Yancy::Plugin::Editor', {
  model => $model,
  storage => $storage,
};
### /Mojolicious::Plugin::Yancy

app->start;
__DATA__
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.conditional.min.css">
    <!-- XXX: This style tag should be provided by a helper -->
    <link rel="stylesheet" href="/editor/editor.css">
  </head>
  <body>
    <div class="pico">
      <main><%= content %></main>
    </div>

    <!-- XXX: These script tags should be provided by a helper -->
    %= javascript type => 'module', defer => '', src => '/editor/iframe.es.js'
    <script>
      window.Yancy ||= {};
      Yancy.allowOrigins = [new RegExp("http://localhost:\\d+"), new RegExp("http://127\\.0\\.0\\.1:\\d+")];
    </script>
  </body>
</html>

@@ page.html.ep
% layout "default";
<h1><%= title %></h1>
%= block page => {}, begin
Put your content here
% end
