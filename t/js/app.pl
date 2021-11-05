
use Mojolicious::Lite;
plugin Yancy => {
  backend => 'memory://',
  schema => {
    user => {
      'x-id-field' => 'username',
      properties => {
        username => {
          type => 'string',
        },
        email => {
          type => 'string',
          format => 'email',
        },
        avatar => {
          type => 'string',
          format => 'path',
        },
      },
    },
  },
  editor => { require_user => undef },
};

get '/new_editor';

app->start;
__DATA__

@@ new_editor.html.ep
% use Mojo::JSON qw( to_json );
%= javascript src => '/main.bundle.js'
%= javascript begin
  let editor = document.createElement( 'yancy-editor' );
  editor.schema = <%== to_json app->yancy->model->json_schema %>;

  window.addEventListener('DOMContentLoaded', (event) => {
    document.body.appendChild( editor );
  });
% end
