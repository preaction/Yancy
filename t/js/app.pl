
use Mojolicious::Lite;
plugin Yancy => {
  backend => 'memory://',
  schema => {
    user => {
      'x-id-field' => 'username',
      required => [qw( username )],
      properties => {
        username => {
          title => 'Username',
          description => q{The user's login name},
          type => 'string',
          minLength => 6,
          maxLength => 100,
          pattern => '^\w+$',
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

for my $schema_name ( keys %{ app->yancy->model->json_schema } ) {
  my $id_field = app->yancy->model( $schema_name )->id_field;
  my @id_fields = ref $id_field eq 'ARRAY' ? ( @$id_field ) : ( $id_field );
  my $id = join '/', map ":$_", @id_fields;
  my @to = ( schema => $schema_name, controller => 'yancy', format => 'json', action => );
  get   "/$schema_name"      => { @to => 'list'   };
  post  "/$schema_name/$id"  => { @to => 'set', map { $_ => undef } @id_fields };
  get   "/$schema_name/$id"  => { @to => 'get'    };
  del   "/$schema_name/$id"  => { @to => 'delete' };
}

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
