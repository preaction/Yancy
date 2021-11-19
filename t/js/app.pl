
use Mojolicious::Lite;
plugin Yancy => {
  backend => 'memory://',
  schema => {
    user => {
      'x-id-field' => 'username',
      properties => {
        username => {
          title => 'Username',
          description => q{The user's login name},
          type => 'string',
          minLength => 6,
          maxLength => 100,
          pattern => '^[[:alpha:]]+$',
          'x-order' => 1,
        },
        age => {
          type => 'integer',
          minimum => 13,
          maximum => 120,
          'x-order' => 3,
        },
        email => {
          type => 'string',
          format => 'email',
          'x-order' => 2,
        },
        url => {
          type => 'string',
          format => 'url',
          'x-order' => 4,
        },
        phone => {
          type => 'string',
          format => 'tel',
          'x-order' => 5,
        },
        discount => {
          type => 'number',
          'x-order' => 6,
        },
      },
    },
  },
  editor => { require_user => undef },
};

app->yancy->model( 'user' )->create({
  username => 'preaction',
});

get   '/new_editor';
get   '/:schema'      => { controller => 'yancy', action => 'list'             };
post  '/:schema/:id'  => { controller => 'yancy', action => 'set', id => undef };
get   '/:schema/:id'  => { controller => 'yancy', action => 'get'              };
del   '/:schema/:id'  => { controller => 'yancy', action => 'delete'           };

app->start;
__DATA__

@@ new_editor.html.ep
% use Mojo::JSON qw( to_json );
%= javascript src => '/main.bundle.js'
%= javascript begin
  let editor = document.createElement( 'yancy-editor' );
  editor.root = '<%== url_for( '/' )->to_abs %>';
  editor.schema = <%== to_json app->yancy->model->json_schema %>;

  window.addEventListener('DOMContentLoaded', (event) => {
    document.body.appendChild( editor );
  });
% end
