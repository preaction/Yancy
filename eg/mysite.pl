
use v5.24;
use Mojolicious::Lite;

plugin Config =>;
plugin Yancy => app->config;

app->start;
