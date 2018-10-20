package Yancy::Plugin::Form::Bootstrap4;
our $VERSION = '1.009';
# ABSTRACT: Generate forms using Bootstrap 4

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://localhost/mysite',
        read_schema => 1,
    };
    app->yancy->plugin( 'Form::Bootstrap4' );
    # See Yancy::Controller::Yancy for routing
    app->routes->get( '/people/:id/edit' )->to(
        'yancy#set',
        collection => 'people',
        template => 'edit_people',
    );
    app->start;
    __DATA__
    @@ edit_people.html.ep
    %= $c->yancy->form->form_for( 'people' );

=head1 DESCRIPTION

This plugin generates forms using the L<Bootstrap
4.0|https://getbootstrap.com/docs/4.0/>.

For details on the helpers added by this plugin, see
L<Yancy::Plugin::Form>.

=head1 TEMPLATES

These templates can be overridden by providing your own template with
the same path.

=over

=item yancy/form/bootstrap4/form.html.ep

This template surrounds the form to create the C<< <form> >> element,
list all the fields, and add a submit button. Also includes a CSRF token.

=item yancy/form/bootstrap4/field.html.ep

This template surrounds a single form field to add a C<< <label> >>
element, the appropriate input element(s), and the optional description.

=item yancy/form/bootstrap4/input.html.ep

This template is for single C<< <input> >> elements and the attributes
they need. This is used by field types C<string>, C<number>, C<integer>,
and string fields with formats C<email> and C<date-time>.

=item yancy/form/bootstrap4/textarea.html.ep

This template is for single C<< <textarea> >> elements and the
attributes they need. This is used by fields with type C<string> and
format C<textarea>.

=item yancy/form/bootstrap4/select.html.ep

This template is for single C<< <select> >> elements and the attributes
they need. This is used by fields with an C<enum> property.

=item yancy/form/bootstrap4/yesno.html.ep

This template displays a yes/no toggle used for fields of type
C<boolean>.

=back

=head1 SEE ALSO

L<Yancy::Plugin::Form>, L<Yancy>

=cut

use Mojo::Base 'Yancy::Plugin::Form';

sub register {
    my ( $self, $app, $conf ) = @_;
    $self->SUPER::register( $app, $conf );
    push @{$app->renderer->classes}, __PACKAGE__;
}

sub input {
    my ( $self, $c, %opt ) = @_;

    my %attr;
    my $template = 'input';
    my $type = !$opt{type} ? 'string'
             : ref $opt{type} eq 'ARRAY' ? $opt{type}[0]
             : $opt{type};
    my $format = delete $opt{format} // '';

    if ( $opt{ enum } ) {
        $template = 'select';
    }
    elsif ( $type eq 'boolean' ) {
        $template = 'yesno';
    }
    elsif ( $type eq 'integer' || $type eq 'number' ) {
        $attr{ type } = 'number';
        $attr{ inputmode } = 'decimal';
        if ( $type eq 'integer' ) {
            # Enable numeric input mode on iOS with pattern attribute
            # https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/
            $opt{ pattern } ||= '[0-9]*';
            $attr{ inputmode } = 'numeric';
        }
    }
    elsif ( $type eq 'string' ) {
        $attr{ type } = $format;
        if ( $format eq 'textarea' ) {
            $template = 'textarea';
        }
        elsif ( $format eq 'email' ) {
            $opt{ pattern } ||= '[^@]+@[^@]+';
            $attr{ inputmode } = 'email';
        }
        elsif ( $format eq 'date-time' ) {
            $attr{ type } = 'datetime-local';
        }
        elsif ( $format eq 'markdown' ) {
            $template = 'markdown';
        }
    }

    # ; use Data::Dumper;
    # ; say Dumper \%opt;
    # ; say Dumper \%attr;

    my $path = join '/', qw( yancy form bootstrap4 ), $template;
    my $html = $c->render_to_string(
        template => $path,
        %opt, %attr,
    );

    # ; say $html;

    return $html;
}

sub field_for {
    my ( $self, $c, $coll, $prop, %opt ) = @_;

    # ; use Data::Dumper;
    # ; say Dumper \%opt;
    my $required = !!grep { $_ eq $prop }
        @{ $c->yancy->schema( $coll )->{required} // [] };

    my $field = $c->yancy->schema( $coll, $prop );
    my $input = $c->yancy->form->input(
        %$field,
        name => $prop,
        id => "field-$coll-$prop",
        ( $required ? ( required => $required ) : () ),
        ( $opt{class} ? ( class => $opt{class} ) : () ),
    );

    my $path = join '/', qw( yancy form bootstrap4 field );
    my $html = $c->render_to_string(
        template => $path,
        %opt,
        id => "field-$coll-$prop",
        name => $prop,
        required => $required,
        content => $input,
    );

    # ; say $html;

    return $html;
}

sub form_for {
    my ( $self, $c, $coll, %opt ) = @_;

    my $props = $c->yancy->schema( $coll )->{properties};
    my @sorted_props
        = sort {
            ( $props->{$a}{'x-order'}//2**31 ) <=> ( $props->{$b}{'x-order'}//2**31 )
        }
        keys %$props;
    my @fields;
    for my $field ( @sorted_props ) {
        push @fields, $c->yancy->form->field_for( $coll, $field );
    }

    my $path = join '/', qw( yancy form bootstrap4 form);
    my $html = $c->render_to_string(
        template => $path,
        %opt,
        fields => \@fields,
    );

    # ; say $html;

    return $html;
}

__DATA__

@@ yancy/form/bootstrap4/input.html.ep
<% my @attrs = qw(
    type pattern required minlength maxlength min max readonly placeholder
    disabled id inputmode
);
%><input class="form-control<%= stash( 'class' ) ? ' '.stash('class') : '' %>"<%
for my $attr ( grep { defined stash $_ } @attrs ) {
%> <%= $attr %>="<%= stash $attr %>" <% } %> />

@@ yancy/form/bootstrap4/textarea.html.ep
<% my @attrs = qw( required readonly disabled id );
%><textarea class="form-control<%= stash( 'class' ) ? ' '.stash('class') : '' %>"<%
for my $attr ( grep { defined stash $_ } @attrs ) {
%> <%= $attr %>="<%= stash $attr %>" <% } %> rows="5"></textarea>

@@ yancy/form/bootstrap4/select.html.ep
<% my @attrs = qw( required readonly disabled id );
%><select class="custom-select<%= stash( 'class' ) ? ' '.stash('class') : '' %>"<%
for my $attr ( grep { defined stash $_ } @attrs ) {
%> <%= $attr %>="<%= stash $attr %>" <% } %>>
    % if ( stash 'required' ) {
    <option value="">- empty -</option>
    % }
    % for my $val ( @{ stash( 'enum' ) || [] } ) {
    <option><%= $val %></option>
    % }
</select>

@@ yancy/form/bootstrap4/yesno.html.ep
<div class="btn-group yes-no">
    <label class="btn btn-xs<%= !!stash('value') ? ' btn-success active' : ' btn-outline-success' %>">
        <input type="radio" name="<%= $name %>" value="1"
            <%= !!stash( 'value' ) ? 'selected="selected"' : '' =%>
        > Yes
    </label>
    <label class="btn btn-xs<%= !stash('value') ? ' btn-outline-danger' : ' btn-danger active' %>">
        <input type="radio" name="<%= $name %>" value="0"
            <%= !stash( 'value' ) ? 'selected="selected"' : '' =%>
        > No
    </label>
</div>

@@ yancy/form/bootstrap4/field.html.ep
<div class="form-group">
    <label for="<%= $id %>"><%= stash( 'title' ) || $name %><%=
        $required ? " *": "" %></label>
    <%= $content %><%
    if ( my $text = stash( 'description' ) ) {
    =%><small class="form-text text-muted"><%= $text =%></small><% } =%>
</div>

@@ yancy/form/bootstrap4/form.html.ep
<% my @attrs = qw( method action id );
%><form<%
for my $attr ( grep { defined stash $_ } @attrs ) {
%> <%= $attr %>="<%= stash $attr %>" <% } =%>>
    %= csrf_field
    <% for my $field ( @$fields ) { %><%= $field =%><% } =%>
    <button type="submit" class="btn btn-primary">Submit</button>
</form>
