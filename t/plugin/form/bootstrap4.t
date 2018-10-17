
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

my $collections = {
    user => {
        required => [qw( email )],
        properties => {
            id => {
                'x-order' => 1,
                readOnly => 1,
            },
            email => {
                'x-order' => 2,
                pattern => '^[^@]+@[^@]+$',
            },
            password => {
                'x-order' => 3,
                type => 'string',
                format => 'password',
            },
            name => {
                'x-order' => 4,
                description => 'The real name of the person',
            },
            access => {
                type => 'string',
                enum => [qw( user moderator admin )],
                'x-order' => 5,
            },
            username => {
                'x-order' => 6,
                description => 'Identifier to use for login',
            },
        },
    },
};

my ( $backend_url, $backend, %items ) = init_backend(
    $collections,
);


my $t = Test::Mojo->new( 'Yancy', {
    backend => $backend_url,
    collections => $collections,
    read_schema => 1,
} );
$t->app->yancy->plugin( 'Form::Bootstrap4' );

my $plugin = $t->app->yancy->form;

subtest 'input' => sub {

    subtest 'basic string field' => sub {
        my $html = $plugin->input();
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'append classes' => sub {
        my $html = $plugin->input(
            class => 'my-class',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'class' ), 'form-control my-class',
            'bootstrap class is correct';
    };

    subtest 'email' => sub {
        my $html = $plugin->input(
            format => 'email',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'email',
            'string field type attr correct';
        is $field->attr( 'pattern' ), '[^@]+@[^@]+',
            'string field pattern attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'password' => sub {
        my $html = $plugin->input(
            format => 'password',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'password',
            'string field type attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'date-time' => sub {
        my $html = $plugin->input(
            format => 'date-time',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'datetime-local',
            'string field type attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'number' => sub {
        my $html = $plugin->input(
            type => 'number',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'number',
            'string field type attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'integer' => sub {
        my $html = $plugin->input(
            type => 'integer',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'input', 'string field tag correct';
        is $field->attr( 'type' ), 'number',
            'string field type attr correct';
        is $field->attr( 'pattern' ), '^\\d+$',
            'string field pattern attr correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';
    };

    subtest 'textarea' => sub {
        my $html = $plugin->input(
            format => 'textarea',
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'textarea', 'textarea field tag correct';
        is $field->attr( 'class' ), 'form-control',
            'bootstrap class is correct';

        subtest 'class' => sub {
            my $html = $plugin->input(
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
                format => 'textarea',
                readonly => 1,
            );
            my $dom = Mojo::DOM->new( $html );
            my $field = $dom->children->[0];
            is $field->tag, 'textarea', 'textarea field tag correct';
            ok $field->attr( 'readonly' ), 'readonly attribute is present';
        };
    };

    subtest 'enum' => sub {
        my $html = $plugin->input(
            type => 'string',
            enum => [qw( foo bar baz )],
        );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->tag, 'select', 'enum field tag correct';
        is $field->attr( 'class' ), 'custom-select',
            'bootstrap class is correct';
        my @option_texts = $field->children->map( 'text' )->each;
        is_deeply \@option_texts, [qw( foo bar baz )],
            'option texts are correct';
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
    };

};

subtest 'field_for' => sub {

    subtest 'basic string field' => sub {
        my $html = $plugin->field_for( user => 'name' );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        is $field->attr( 'class' ), 'form-group', 'field class correct';
        ok my $label = $dom->at( 'label' ), 'label exists';
        ok $label->attr( 'for' ), 'label has for attribute';
        is $label->text, 'name', 'label text is field name';
        ok my $input = $dom->at( 'input' ), 'input exists';
        is $input->attr( 'id' ), $label->attr( 'for' ), 'input id matches label for';
    };

    subtest 'required field with pattern' => sub {
        my $html = $plugin->field_for( user => 'email' );
        my $dom = Mojo::DOM->new( $html );
        my $field = $dom->children->[0];
        ok my $label = $dom->at( 'label' ), 'label exists';
        is $label->text, 'email *', 'label text is field name with required marker';
        ok my $input = $dom->at( 'input' ), 'input exists';
        is $input->attr( 'pattern' ),
            $collections->{user}{properties}{email}{pattern},
            'input pattern matches collection config';
    };

    subtest 'class goes to input' => sub {
        my $html = $plugin->field_for( user => 'name', class => 'foo' );
        my $dom = Mojo::DOM->new( $html );
        ok my $input = $dom->at( 'input' ), 'input exists';
        like $input->attr( 'class' ), qr{\bfoo\b}, 'input class contains string';
    };
};

subtest 'form_for' => sub {
    my $html = $plugin->form_for( 'user' );
    #; diag $html;
    my $dom = Mojo::DOM->new( $html );
    my $form = $dom->children->[0];

    subtest 'form attribute defaults' => sub {
        ok !$form->attr( 'method' ), 'method is not set';
        ok !$form->attr( 'action' ), 'action is not set';
        ok !$form->attr( 'id' ), 'id is not set';
    };

    subtest 'form fields' => sub {
        my $fields = $dom->find( '.form-group' );
        is $fields->size, 6, 'found 6 fields';
        #; diag $fields->each;
        my $labels = $fields->map( at => 'label' );
        is $labels->size, 6, 'found 6 labels';
        #; diag $labels->each;
        is_deeply [ $labels->map( 'text' )->each ],
            [ 'id', 'email *', 'password', 'name', 'access', 'username' ],
            'label texts in correct order';
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
};

done_testing;

