
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
        },
        age => {
          type => 'integer',
          minimum => 13,
          maximum => 120,
        },
        email => {
          type => 'string',
          format => 'email',
        },
        url => {
          type => 'string',
          format => 'url',
        },
        phone => {
          type => 'string',
          format => 'tel',
        },
        discount => {
          type => 'number',
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
