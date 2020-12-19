
use Mojolicious::Lite -signatures;
use Mojo::JSON qw( true false );

# Download this database: https://github.com/preaction/Yancy/tree/master/eg/cookbook/pages-markdown.sqlite3
plugin Yancy => {
    backend => 'sqlite:pages-markdown.sqlite3',
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
                markdown => {
                    type => 'string',
                    format => 'markdown',
                    'x-html-field' => 'content',
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
