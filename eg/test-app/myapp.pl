
use Mojolicious::Lite;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib path( $Bin, '..', '..', 'lib' )->to_string;
use lib path( $Bin, '..', '..', 't', 'lib' )->to_string;

plugin Config =>;
plugin Yancy => app->config;
for my $plugin ( @{ app->config->{plugins} || [] } ) {
    app->plugin( @$plugin );
}
app->plugin( 'Yancy::Plugin::Form::Bootstrap4' );
app->defaults( layout => 'default' );

app->routes->get( '/people' )->to(
    'yancy#list',
    schema => 'people',
    table => {
        show_filter => 1,
    },
)->name( 'people.list' );
app->routes->get( '/people/:id' )->to(
    'yancy#get',
    schema => 'people',
    template => 'view_people',
)->name( 'people.get' );
app->routes->any( [qw( GET POST )], '/people/:id/edit' )->to(
    'yancy#set',
    schema => 'people',
    template => 'edit_people',
    forward_to => 'people.get',
)->name( 'people.edit' );

app->start;

__DATA__
@@ layouts/default.html.ep
<head>
<link rel="stylesheet" href="/yancy/bootstrap.css">
</head>
<div class="container">
<div class="row">
<main class="col">
%= content
</main>
</div>
</div>

@@ view_people.html.ep
<h1><%= $item->{name} %></h1>
%= link_to 'Edit', 'people.edit'
%= link_to 'Back', 'people.list'

@@ edit_people.html.ep
<h1><%= $item->{name} %></h1>
%= link_to 'Back', 'people.get'
<%= $c->yancy->form->form_for( 'people' ) %>
