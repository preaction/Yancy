
use Mojolicious::Lite;

plugin Config =>;
plugin Yancy => app->config;

app->routes->get( '/people' )->to(
    'yancy#list',
    collection => 'people',
    template => 'list_people',
)->name( 'people.list' );
app->routes->get( '/people/:id' )->to(
    'yancy#get',
    collection => 'people',
    template => 'view_people',
)->name( 'people.get' );

app->start;

__DATA__
@@ list_people.html.ep
<ul>
% for my $person ( @$items ) {
    <li><%= link_to $person->{name}, 'people.get', $person %></li>
% }
</ul>

@@ view_people.html.ep
<h1><%= $item->{name} %></h1>
%= link_to 'Back', 'people.list'
