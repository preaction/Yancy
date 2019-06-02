
use Mojolicious::Lite;

plugin Config =>;
plugin Yancy => app->config;
for my $plugin ( @{ app->config->{plugins} || [] } ) {
    app->yancy->plugin( @$plugin );
}
app->yancy->plugin( 'Form::Bootstrap4' );
app->defaults( layout => 'default' );

app->routes->get( '/people' )->to(
    'yancy#list',
    schema => 'people',
    template => 'list_people',
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

@@ list_people.html.ep
<ul>
% for my $person ( @$items ) {
    <li><%= link_to $person->{name}, 'people.get', $person %></li>
% }
</ul>

@@ view_people.html.ep
<h1><%= $item->{name} %></h1>
%= link_to 'Edit', 'people.edit'
%= link_to 'Back', 'people.list'

@@ edit_people.html.ep
<h1><%= $item->{name} %></h1>
%= link_to 'Back', 'people.get'
<%= $c->yancy->form->form_for( 'people' ) %>
