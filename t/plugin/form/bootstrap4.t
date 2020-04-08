
=head1 DESCRIPTION

Tests the Bootstrap 4 form plugin methods.

=head1 SEE ALSO

L<Yancy::Plugin::Form::Bootstrap4>, L<Yancy::Plugin::Form>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use Mojo::DOM;
use Mojo::File qw( path );
use FindBin qw( $Bin );
use lib "".path( $Bin, '..', '..', 'lib' );
use Local::Test qw( init_backend );

my $schema = \%Yancy::Backend::Test::SCHEMA;

my ( $backend_url, $backend, %items ) = init_backend(
    $schema,
);


my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    schema => $schema,
    read_schema => 1,
} );
$t->app->yancy->plugin( 'Form::Bootstrap4' );

my $plugin = $t->app->yancy->form;

subtest 'input' => sub {

    subtest 'name is required' => sub {
        eval { $plugin->input() };
        ok $@, 'input() method died';
        like $@, qr{input name is required}, 'error message is correct';
    };

    subtest 'basic string field' => sub {
        my $html = $plugin->input( name => 'username', value => 'preaction' );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'text',
            'string field default type attr is correct';
        is $field->attr( 'name' ), 'username',
            'string field name attr is correct';
        is $field->attr( 'value' ), 'preaction',
            'string field value attr is correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';

        subtest 'readonly' => sub {
            my $html = $plugin->input( name => 'id', readOnly => 1, value => 45 );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'p', 'readonly string field tag correct';
            is $field->text, 45, 'readonly string field text is value';
        };
    };

    subtest 'append classes' => sub {
        my $html = $plugin->input(
            name => 'username',
            class => 'my-class',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'username',
            'string field name attr is correct';
        is $field->attr( 'class' ), 'form-control my-class',
            'bootstrap class is correct';
    };

    subtest 'email' => sub {
        my $html = $plugin->input(
            name => 'email',
            format => 'email',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'email',
            'string field name attr is correct';
        is $field->attr( 'type' ), 'email',
            'string field type attr correct';
        is $field->attr( 'inputmode' ), 'email',
            'string field inputmode attr correct';
        is $field->attr( 'pattern' ), '[^@]+@[^@]+',
            'string field pattern attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'password' => sub {
        my $html = $plugin->input(
            name => 'password',
            format => 'password',
            value => 'mypassword',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'password',
            'string field name attr is correct';
        is $field->attr( 'value' ), undef,
            'password field value attr is not set';
        is $field->attr( 'type' ), 'password',
            'string field type attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'date-time' => sub {
        my $html = $plugin->input(
            name => 'created',
            format => 'date-time',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'created',
            'string field name attr is correct';
        is $field->attr( 'type' ), 'datetime-local',
            'string field type attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'number' => sub {
        my $html = $plugin->input(
            name => 'height',
            type => 'number',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'height',
            'string field name attr is correct';
        is $field->attr( 'type' ), 'number',
            'string field type attr correct';
        is $field->attr( 'inputmode' ), 'decimal',
            'string field inputmode attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'integer' => sub {
        my $html = $plugin->input(
            name => 'age',
            type => 'integer',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'name' ), 'age',
            'string field name attr is correct';
        is $field->attr( 'type' ), 'number',
            'string field type attr correct';
        is $field->attr( 'pattern' ), '[0-9]*',
            'string field pattern attr correct';
        is $field->attr( 'inputmode' ), 'numeric',
            'string field inputmode attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'textarea' => sub {
        my $html = $plugin->input(
            name => 'description',
            format => 'textarea',
            value => "my text\non multiple lines",
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'textarea', 'textarea field tag correct';
        is $field->attr( 'name' ), 'description',
            'string field name attr is correct';
        is $field->text, "my text\non multiple lines",
            'textarea value is correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';

        subtest 'class' => sub {
            my $html = $plugin->input(
                name => 'description',
                format => 'textarea',
                class => 'foo',
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'textarea', 'textarea field tag correct';
            is $field->attr( 'class' ), 'form-control foo',
                'bootstrap class is correct and has our custom class';
        };

        subtest 'disabled' => sub {
            my $html = $plugin->input(
                name => 'description',
                format => 'textarea',
                disabled => 1,
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'textarea', 'textarea field tag correct';
            ok $field->attr( 'disabled' ), 'disabled attribute is present';
        };

        subtest 'readonly' => sub {
            my $html = $plugin->input(
                name => 'description',
                format => 'textarea',
                readonly => 1,
                value => "Text\nArea",
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'p', 'readonly textarea field tag correct';
            is $field->text, "Text\nArea", 'readonly textarea value is correct';
        };
    };

    subtest 'enum' => sub {
        my $html = $plugin->input(
            name => 'varname',
            type => 'string',
            enum => [qw( foo bar baz )],
            value => 'bar',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'select', 'enum field tag correct';
        is $field->attr( 'name' ), 'varname',
            'select field name attr is correct';
        is $field->attr( 'class' ), 'custom-select',
            'bootstrap class is correct';
        my @option_texts = $field->children->map( 'text' )->each;
        is_deeply \@option_texts, [qw( foo bar baz )],
            'option texts are correct';
        ok my $selected_option = $field->at( 'option[selected=selected]' ),
            'selected option exists';
        is $selected_option->text, 'bar',
            'selected option text is correct';

        subtest 'readonly' => sub {
            my $html = $plugin->input(
                name => 'varname',
                type => 'string',
                value => 'bar',
                enum => [qw( foo bar baz )],
                readOnly => 1,
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'p', 'readonly select field tag correct';
            is $field->text, 'bar', 'readonly select field value correct';
        };
    };

    subtest 'boolean' => sub {
        my $html = $plugin->input(
            type => 'boolean',
            name => 'myname',
            value => 0,
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'div', 'boolean field tag correct';
        is $field->attr( 'class' ), 'btn-group yes-no',
            'bootstrap class is correct';

        my @labels = $field->children->each;
        is $labels[0]->tag, 'label', 'label tag (Yes) is correct';
        like $labels[0]->text, qr{^\s*Yes\s*$}, 'label text (Yes) is correct';
        is $labels[1]->tag, 'label', 'label tag (No) is correct';
        like $labels[1]->text, qr{^\s*No\s*$}, 'label text (No) is correct';
        is $labels[0]->children->[0]->tag, 'input', 'input tag (Yes) is correct';
        is $labels[1]->children->[0]->tag, 'input', 'input tag (No) is correct';
        is $labels[0]->children->[0]->attr( 'name' ), 'myname',
            'input name attr (Yes) is correct';
        is $labels[1]->children->[0]->attr( 'name' ), 'myname',
            'input name attr (No) is correct';
        is $labels[0]->children->[0]->attr( 'value' ), '1',
            'input value attr (Yes) is correct';
        is $labels[1]->children->[0]->attr( 'value' ), '0',
            'input value attr (No) is correct';
        ok !$labels[0]->children->[0]->attr( 'selected' ),
            'input is not selected (Yes)';
        is $labels[1]->children->[0]->attr( 'selected' ), 'selected',
            'input is selected (No)';

        subtest 'readonly' => sub {
            my $html = $plugin->input(
                type => 'boolean',
                name => 'myname',
                value => 0,
                readOnly => 1,
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'p', 'readonly tag is correct';
            is $field->text, 'No', 'false is "No"';
        };
    };

    subtest 'markdown' => sub {
        my $html = $plugin->input(
            name => 'bio',
            format => 'markdown',
            value => "my text\non *multiple* lines",
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'textarea', 'textarea field tag correct';
        is $field->attr( 'name' ), 'bio',
            'string field name attr is correct';
        is $field->text, "my text\non *multiple* lines",
            'markdown value is correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

};

subtest 'field_for' => sub {

    subtest 'basic string field' => sub {
        my $html = $plugin->field_for( user => 'age', value => '42' );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->attr( 'class' ), 'form-group', 'field class correct';
        ok my $label = $dom->at( 'label' ), 'label exists';
        ok $label->attr( 'for' ), 'label has for attribute';
        is $label->text, 'age', 'label text is field name';
        ok my $input = $dom->at( 'input' ), 'input exists';
        is $input->attr( 'id' ), $label->attr( 'for' ), 'input id matches label for';
        is $input->attr( 'name' ), 'age', 'input name correct';
        is $input->attr( 'value' ), '42', 'input value correct';
        ok my $desc = $dom->at( '.form-group .form-text' ), 'description exists';
        is $desc->text, 'The person\'s age',
            'description text is correct';
    };

    subtest 'readonly field' => sub {
        my $html = $plugin->field_for( user => 'id', value => 1 );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        ok my $input = $dom->at( 'p[data-name=id]' ), 'paragraph exists';
        is $input->text, 1, 'paragraph text correct';
    };

    subtest 'required field with title and pattern' => sub {
        my $html = $plugin->field_for( user => 'email' );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        ok my $label = $dom->at( 'label' ), 'label exists';
        is $label->text, 'E-mail Address *',
            'label text is field title with required marker';
        ok my $input = $dom->at( 'input' ), 'input exists';
        is $input->attr( 'name' ), 'email', 'input name correct';
        is $input->attr( 'pattern' ),
            $schema->{user}{properties}{email}{pattern},
            'input pattern matches schema config';
    };

    subtest 'class goes to input' => sub {
        my $html = $plugin->field_for( user => 'name', class => 'foo' );
        my $dom = Mojo::DOM->new( $html );
        ok my $input = $dom->at( 'input' ), 'input exists';
        like $input->attr( 'class' ), qr{\bfoo\b}, 'input class contains string';
    };
};

subtest 'form_for' => sub {
    my %item = (
        id => 1,
        email => 'doug@example.com',
        password => 'sdfsdfsdfsdf',
        access => 'user',
        username => 'preaction',
        age => 35,
        plugin => 'password',
    );
    my $html = $plugin->form_for( 'user', item => \%item );
    #; diag $html;
    my $dom = Mojo::DOM->new( $html );
    my $form = $dom->children->[0];

    subtest 'form attribute defaults' => sub {
        is $form->attr( 'method' ), 'POST', 'default method is "POST"';
        ok !$form->attr( 'action' ), 'action is not set';
        ok !$form->attr( 'id' ), 'id is not set';
    };

    subtest 'form fields' => sub {
        my $fields = $dom->find( '.form-group' );
        is $fields->size, 9, 'found 10 fields';
        #; diag $fields->each;
        my $labels = $fields->map( at => 'label' )->grep( sub { defined } );
        is $labels->size, 9, 'found 10 labels';
        #; diag $labels->each;
        is_deeply [ $labels->map( 'text' )->each ],
            [ 'id', 'username *', 'E-mail Address *', 'password *', 'access', 'age', 'plugin', 'avatar', 'created' ],
            'label texts in correct order';
        my $inputs = $fields->map( at => 'input,select,textarea' )->grep( sub { defined } );
        is $inputs->size, 8, 'found 9 inputs (1 is read-only)';
        is_deeply [ $inputs->map( attr => 'name' )->each ],
            [ 'username', 'email', 'password', 'access', 'age', 'plugin', 'avatar', 'created' ],
            'input names in correct order';

        my $id_input = $dom->at( 'p[data-name=id]' );
        is $id_input->text, $item{ id },
            'id field value is correct';

        my $email_input = $dom->at( 'input[name=email]' );
        is $email_input->attr( 'type' ), 'email',
            'email field type is correct';
        is $email_input->attr( 'value' ), $item{ email },
            'email field value is correct';

        my $username_input = $dom->at( 'input[name=username]' );
        is $username_input->attr( 'value' ), $item{ username },
            'username field value is correct';

        my $password_input = $dom->at( 'input[name=password]' );
        is $password_input->attr( 'value' ), undef,
            'password field value is not set to avoid security issues';

        my $access_input = $dom->at( 'select[name=access]' );
        ok my $selected_option = $access_input->at( 'option[selected]' ),
            'access select field has selected option';
        is $selected_option->text, 'user', 'selected option value is correct';
    };

    subtest 'buttons' => sub {
        ok my $button = $dom->at( 'button' ), 'button exists';
        is $button->text, 'Submit', 'button text is correct';
    };

    subtest 'set form element attributes' => sub {
        my $html = $plugin->form_for( 'user',
            action => '/user/1',
            method => 'POST',
        );
        my $dom = Mojo::DOM->new( $html );
        my $form = $dom->children->[0];

        is $form->attr( 'method' ), 'POST', 'method is set from args';
        is $form->attr( 'action' ), '/user/1', 'action is set from args';
    };

    subtest 'default item from stash' => sub {
        my $c = $t->app->build_controller;
        $c->stash( item => \%item );

        my $html = Yancy::Plugin::Form::Bootstrap4->form_for( $c, 'user' );
        #; diag $html;
        my $dom = Mojo::DOM->new( $html );
        my $form = $dom->children->[0];

        my $fields = $dom->find( '.form-group' );
        is $fields->size, 9, 'found 9 fields';
        my $labels = $fields->map( at => 'label' )->grep( sub { defined } );
        is $labels->size, 9, 'found 9 labels';
        my $inputs = $fields->map( at => 'input,select,textarea' )->grep( sub { defined } );
        is $inputs->size, 8, 'found 8 inputs (1 is read-only)';

        my $email_input = $dom->at( 'input[name=email]' );
        is $email_input->attr( 'type' ), 'email',
            'email field type is correct';
        is $email_input->attr( 'value' ), $item{ email },
            'email field value is correct';
    };
    
    subtest 'form_for skip_fields option' => sub {
        my $html = $plugin->form_for( 'user', item => \%item, skip_fields => [qw/id access plugin/] );
        my $dom  = Mojo::DOM->new($html);
        my $form = $dom->children->[0];
        is $dom->at('input[name=id]'),     undef;
        is $dom->at('input[name=access]'), undef;
        is $dom->at('input[name=plugin]'), undef;
        ok $dom->at('input[name=email]');
        ok $dom->at('input[name=password]');
        ok $dom->at('input[name=username]');
        ok $dom->at('input[name=age]');
    }
};

subtest 'default form plugin' => sub {
    my $t = Test::Mojo->new( 'Yancy', {
        backend => $backend_url,
        schema => $schema,
        read_schema => 1,
    } );
    ok +( grep { /Yancy::Plugin::Form::Bootstrap4/ }
        @{ $t->app->renderer->classes }
    ), 'app renderer has bootstrap4 class';
};

done_testing;

