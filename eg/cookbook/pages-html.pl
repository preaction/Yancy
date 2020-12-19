
use Mojolicious::Lite -signatures;
use Mojo::JSON qw( true false );

# Download this database: https://github.com/preaction/Yancy/tree/master/eg/cookbook/pages.sqlite3
plugin Yancy => {
    backend => 'sqlite:pages.sqlite3',
    read_schema => 1,
    schema => {
        pages => {
            title => 'Pages',
            description => 'These are the pages in your site.',
            'x-id-field' => 'path',
            required => [qw( path content )],
            properties => {
                page_id => {
                    type => 'integer',
                    readOnly => true,
                },
                path => {
                    type => 'string',
                },
                content => {
                    type => 'string',
                    format => 'html',
                },
            },
        },
    },
};

app->routes->get( '/*path', { path => 'index' } )->to({
    controller => 'Yancy',
    action => 'get',
    schema => 'pages',
    template => 'page',
});

app->start;
__DATA__
@@ page.html.ep
%== $item->{content}
