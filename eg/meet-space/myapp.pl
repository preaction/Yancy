#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite -signatures;
use lib 'lib', '../../lib';

# These are annotations that will be added to the JSON Schema.
# TODO: Maybe we should auto-load from a file or allow loading from a file?
my %model_schema = (
  news_posts => {
    'x-view-url' => '/news',
    'x-view-item-url' => '/news/{slug}',
    'x-list-columns' => [qw( slug title publish_datetime )],
    properties => {
      description => {
        type => "string", format => "markdown",
        'x-html-field' => 'description_html',
      },
      content => {
        type => "string", format => "markdown",
        'x-html-field' => 'content_html',
      },
      publish_datetime => {
        type => "string", format => "date-time",
        default => 'now',
      },
    },
  },
  calendars => {
    'x-list-columns' => [qw( title description )],
    properties => {
      description => {
        format => 'textarea',
      },
    },
  },
  events => {
    'x-view-url' => '/events',
    'x-view-item-url' => '/events/{slug}',
    'x-list-columns' => [qw( slug title calendar_id start_datetime end_datetime )],
    properties => {
      description => {
        type => "string", format => "markdown",
        'x-html-field' => 'description_html',
      },
      description_html => { 'x-hidden' => 1 },
      content => {
        type => "string", format => "markdown",
        'x-html-field' => 'content_html',
      },
      content_html => { 'x-hidden' => 1 },
      calendar_id => {
        type => 'integer',
        'x-foreign-key' => 'calendars',
        'x-display-field' => 'title',
      }
    },
  },
  locations => {
    'x-list-columns' => [qw( title description address )],
  },
);

### Mojolicious::Plugin::Yancy
# XXX: This should be all handled by Mojolicious::Plugin::Yancy 
use Mojo::SQLite;
my $db = Mojo::SQLite->new('sqlite::temp:');
$db->migrations->from_data->migrate;

use Yancy::Backend::Sqlite;
my $backend = Yancy::Backend::Sqlite->new($db);
$backend->read_schema;
# XXX: Should not have to read_schema on backend

use Yancy::Model;
my $db_model = Yancy::Model->new(
  backend => $backend,
  schema => \%model_schema,
);

unshift @{ $db_model->namespaces }, 'MyApp';
# XXX: Should not have to re-read schema after adjusting namespaces
$db_model->read_schema;

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

### App-specific routes
# Content-only routes
get '/' => {
  template => 'home',
  layout => 'default',
  title => 'A space to meet',
}, 'home';
get '/about' => {
  template => 'about',
  layout => 'about',
  title => 'About Us'
}, 'about';
get '/about/history' => {
  template => 'history',
  layout => 'about',
  title => 'Our History',
}, 'history';
get '/about/contact' => {
  template => 'contact',
  layout => 'about',
  title => 'Contact Us',
}, 'contact';
get '/about/privacy' => {
  template => 'privacy',
  layout => 'about',
  title => 'Privacy Policy',
}, 'privacy';

# Model-based routes
get '/news' => {
  controller => 'yancy',
  action => 'list',
  schema => 'news_posts',
  template => 'news',
  layout => 'default',
}, 'news';
get '/news/:slug' => {
  controller => 'yancy',
  action => 'get',
  schema => 'news_posts',
  template => 'news-post',
  layout => 'default',
}, 'news-post';
get '/events' => {
  controller => 'yancy',
  action => 'list',
  schema => 'events',
  template => 'events',
  layout => 'default',
}, 'events';
get '/events/:slug' => {
  controller => 'yancy',
  action => 'get',
  schema => 'events',
  template => 'event-details',
  layout => 'default',
}, 'event-details';

app->start;

__DATA__

@@ migrations
-- 1 up
CREATE TABLE locations (
  location_id INTEGER PRIMARY KEY AUTOINCREMENT,
  title STRING,
  description STRING,
  address STRING,
  plus_code STRING,
  CONSTRAINT location_plus_code UNIQUE (plus_code)
);

CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  calendar_id INTEGER REFERENCES calendars(calendar_id) ON DELETE SET DEFAULT,
  title STRING,
  slug STRING NOT NULL,
  description STRING,
  description_html STRING,
  content STRING,
  content_html STRING,
  start_datetime STRING,
  end_datetime STRING,
  schedule STRING,
  UNIQUE (slug)
);

CREATE TABLE event_locations (
  event_id INTEGER NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
  location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
  description STRING,
  description_html STRING,
  PRIMARY KEY (event_id, location_id)
);

CREATE TABLE calendars (
  calendar_id INTEGER PRIMARY KEY AUTOINCREMENT,
  title STRING,
  description STRING
);

CREATE TABLE news_posts (
  news_post_id INTEGER PRIMARY KEY AUTOINCREMENT,
  title STRING NOT NULL,
  slug STRING NOT NULL,
  description STRING,
  description_html STRING,
  content STRING,
  content_html STRING,
  publish_datetime STRING,
  UNIQUE (slug)
);

-- 1 down
DROP TABLE news_posts;
DROP TABLE calendars;
DROP TABLE event_locations;
DROP TABLE events;
DROP TABLE locations;

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %> - Meet Space</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  </head>
  <body>
    %= include 'partials/nav'
    %= content 'submenu'
    <main class="container">
      %= content
    </main>
    %= include 'partials/footer'

    <!-- XXX: These script tags should be provided by a helper -->
    <script src="/iframe/index.js"></script>
    <script>
      Yancy.allowOrigins = [new RegExp("http://localhost:\\d+"), new RegExp("http://127\\.0\\.0\\.1:\\d+")];
    </script>

  </body>
</html>

@@ layouts/about.html.ep
<%
  extends 'layouts/default';
%>
% content_for submenu => begin
<nav class="container" aria-label="Section">
  <ul>
    <li><%= link_to about => begin %>About Us<% end %></li>
    <li><%= link_to history => begin %>Our History<% end %></li>
    <li><%= link_to contact => begin %>Contact Us<% end %></li>
    <li><%= link_to privacy => begin %>Privacy Policy<% end %></li>
  </ul>
</nav>
% end

@@ partials/nav.html.ep
<nav class="container" aria-label="Main">
  <ul>
    <li><%= link_to home => begin %>Meet Space<% end %></li>
  </ul>
  <ul>
    <li><%= link_to news => begin %>News<% end %></li>
    <li><%= link_to events => begin %>Events<% end %></li>
    <li><%= link_to about => begin %>About Us<% end %></li>
  </ul>
</nav>

@@ partials/footer.html.ep
<footer class="container">
</footer>

@@ home.html.ep
<%
%>
<div class="grid">
  <section>
    <hgroup>
      <h1>Meet Space</h1>
      <small>A Space to Meet</small>
    </hgroup>
    %= block 'home-about', {}, begin
      <p>An editable about us blurb for the front page.</p>
    % end
    %= link_to about => begin
      More about us...
    %= end
  </section>

  <section>
    <h2>Latest News</h2>
    <p>A widget containing the first news post with the published time after right now.</p>
  </section>
</div>

@@ about.html.ep
<%
%>
<h1>About Meet Space</h1>

@@ history.html.ep
<%
%>
<h1>Our History</h1>

@@ contact.html.ep
<%
%>
<h1>Contact Us</h1>

@@ privacy.html.ep
<%
%>
<h1>Privacy Policy</h1>

@@ news.html.ep
<%
%>
<h1>News</h1>

@@ news-post.html.ep

@@ events.html.ep
<h1>Events</h1>

@@ event-details.html.ep

