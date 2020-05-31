package Yancy::Plugin::Form::Bootstrap4;
our $VERSION = '1.058';
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
        schema => 'people',
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

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 yancy/form/bootstrap4/form.html.ep

This template surrounds the form to create the C<< <form> >> element,
list all the fields, and add a submit button. Also includes a CSRF token.

=head2 yancy/form/bootstrap4/field.html.ep

This template surrounds a single form field to add a C<< <label> >>
element, the appropriate input element(s), and the optional description.

=head2 yancy/form/bootstrap4/input.html.ep

This template is for single C<< <input> >> elements and the attributes
they need. This is used by field types C<string>, C<number>, C<integer>,
and string fields with formats C<email> and C<date-time>.

=head2 yancy/form/bootstrap4/textarea.html.ep

This template is for single C<< <textarea> >> elements and the
attributes they need. This is used by fields with type C<string> and
format C<textarea>.

=head2 yancy/form/bootstrap4/select.html.ep

This template is for single C<< <select> >> elements and the attributes
they need. This is used by fields with an C<enum> property.

=head2 yancy/form/bootstrap4/yesno.html.ep

This template displays a yes/no toggle used for fields of type
C<boolean>.

=head2 yancy/form/bootstrap4/readonly.html.ep

This template displays all read-only fields. This template must not include
any kind of C<< <input> >>, C<< <select> >>, or other form fields.

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

    die "input name is required" unless $opt{name};
    $opt{value} //= $c->req->param( $opt{name} );

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
        $attr{ type } = $format || 'text';
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
        elsif ( $format eq 'password' ) {
            delete $opt{ value };
        }
    }

    if ( my $readonly = ( delete $opt{ readOnly } or delete $opt{ readonly } ) ) {
        $template = 'readonly';
    }

    # ; use Data::Dumper;
    # ; say Dumper \%opt;
    # ; say Dumper \%attr;

    my $path = join '/', qw( yancy form bootstrap4 ), $template;
    my $html = $c->render_to_string(
        template => $path,
        input => { %opt, %attr },
    );

    # ; say $html;

    return $html;
}

sub input_for {
    my ( $self, $c, $coll, $prop, %opt ) = @_;
    my $schema = $c->yancy->schema( $coll );
    my $required = exists $opt{required} ? $opt{required} : !!grep { $_ eq $prop } @{ $schema->{required} // [] };

    my $field = $schema->{properties}{ $prop };
    my $input = $self->input( $c,
        %$field,
        ( type => $opt{type} )x!!exists $opt{type},
        ( enum => $opt{enum} )x!!exists $opt{enum},
        ( format => $opt{format} )x!!exists $opt{format},
        ( enum_labels => $opt{ enum_labels } )x!!exists $opt{enum_labels},
        name => $prop,
        value => $opt{value},
        ( $required ? ( required => $required ) : () ),
        ( $opt{class} ? ( class => $opt{class} ) : () ),
    );
}

sub filter_for {
    my ( $self, $c, $coll, $prop, %opt ) = @_;
    my $schema = $c->yancy->schema( $coll );
    my $field = $schema->{properties}{ $prop };
    if ( $field->{type} eq 'boolean' ) {
        $opt{ type } = 'string';
        $opt{ enum } = [ undef, 1, 0 ];
        $opt{ enum_labels } = [ undef, 'Yes', 'No' ];
    }
    $opt{format} = undef;
    $opt{ value } //= $c->req->param( $prop );
    $opt{required} = 0;
    return $self->input_for( $c, $coll, $prop, %opt );
}

sub field_for {
    my ( $self, $c, $coll, $prop, %opt ) = @_;

    # ; use Data::Dumper;
    # ; say Dumper \%opt;
    my $schema = $c->yancy->schema( $coll );
    my $required = !!grep { $_ eq $prop } @{ $schema->{required} // [] };

    my $field = $schema->{properties}{ $prop };
    my $input = $self->input( $c,
        %$field,
        name => $prop,
        value => $opt{value},
        id => "field-$coll-$prop",
        ( $required ? ( required => $required ) : () ),
        ( $opt{class} ? ( class => $opt{class} ) : () ),
    );

    my $path = join '/', qw( yancy form bootstrap4 field );
    my $html = $c->render_to_string(
        template => $path,
        field => {
            %$field,
            %opt,
            id => "field-$coll-$prop",
            name => $prop,
            required => $required,
            content => $input,
        },
    );

    # ; say $html;

    return $html;
}

sub form_for {
    my ( $self, $c, $coll, %opt ) = @_;

    my $item = $opt{ item } || $c->stash( 'item' ) || {};
    my $props = $c->yancy->schema( $coll )->{properties};

    my $prop_names = $opt{properties} // $c->stash( 'properties' )
        # By default, do not show read-only fields
        // [ grep !$props->{$_}{readOnly}, keys %$props ];
    $props = {
        map { $_ => $props->{ $_ } }
        @$prop_names
    };

    my @sorted_props
        = sort {
            ( $props->{$a}{'x-order'}//2**31 ) <=> ( $props->{$b}{'x-order'}//2**31 )
        }
        keys %$props;
    my @fields;
    for my $field ( @sorted_props ) {
        my %field_opt = (
            value => $c->req->param( $field ) // $item->{ $field },
        );
        push @fields, $self->field_for( $c, $coll, $field, %field_opt );
    }

    if ( !exists $opt{csrf} || $opt{csrf} ) {
        # Verify that this form is being built with a real request
        # so the CSRF field can work correctly
        if ( !$c->tx->remote_address ) {
            $c->log->warn( 'form_for() called with incomplete request. CSRF token may not validate!');
        }
    }

    my $path = join '/', qw( yancy form bootstrap4 form);
    my $html = $c->render_to_string(
        template => $path,
        form => {
            method => 'POST',
            csrf => 1,
            %opt,
            fields => \@fields,
        },
    );

    # ; say $html;

    return $html;
}

__DATA__

@@ yancy/form/bootstrap4/input.html.ep
<%  my $input = stash( 'input' );
    my @found_attrs =
        grep { defined $input->{ $_ } }
        qw(
            type pattern required minlength maxlength min max readonly placeholder
            disabled id inputmode name value
        );
%><input class="form-control<%= $input->{class} ? ' '.$input->{class} : '' %>"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{ $attr } %>" <% } %> />

@@ yancy/form/bootstrap4/markdown.html.ep
<%  my $input = stash( 'input' );
    my @found_attrs =
        grep { defined $input->{ $_ } }
        qw( required readonly disabled id name );
%><textarea class="form-control<%= $input->{class} ? ' '.$input->{class} : '' %>"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{$attr} %>" <% } %> rows="5"><%= $input->{value} %></textarea>

@@ yancy/form/bootstrap4/textarea.html.ep
<%  my $input = stash( 'input' );
    my @found_attrs =
        grep { defined $input->{ $_ } }
        qw( required readonly disabled id name );
%><textarea class="form-control<%= $input->{class} ? ' '.$input->{class} : '' %>"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{$attr} %>" <% } %> rows="5"><%= $input->{value} %></textarea>

@@ yancy/form/bootstrap4/select.html.ep
<%  my $input = stash( 'input' );
    my @found_attrs =
        grep { defined $input->{ $_ } }
        qw( required readonly disabled id name );
%><select class="custom-select<%= $input->{class} ? ' '.$input->{class} : '' %>"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{ $attr } %>" <% } %>>
    % if ( $input->{ required } ) {
    <option value="">- empty -</option>
    % }
    % for my $i ( 0..$#{ $input->{enum} || [] } ) {
        % my $val = $input->{enum}[ $i ];
        % my $label = $input->{enum_labels}[ $i ] // $val;
    <option value="<%= $val %>"<%== defined $input->{value} && $val eq $input->{value} ? ' selected="selected"' : ''
    %>><%= $label %></option>
    % }
</select>

@@ yancy/form/bootstrap4/yesno.html.ep
<%  my $input = stash( 'input' );
    my @found_attrs =
        grep { defined $input->{ $_ } }
        qw( required readonly disabled name );
    my $value = $input->{value};
%><div class="btn-group yes-no">
    <label class="btn btn-xs<%= !!$value ? ' btn-success active' : ' btn-outline-success' %>">
        <input type="radio" name="<%= $input->{name} %>" value="1"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{ $attr } %>"<% }
%><%== !!$value ? ' selected="selected"' : '' =%>> Yes
    </label>
    <label class="btn btn-xs<%= !$value ? ' btn-outline-danger' : ' btn-danger active' %>">
        <input type="radio" name="<%= $input->{name} %>" value="0"<%
for my $attr ( @found_attrs ) {
%> <%= $attr %>="<%= $input->{ $attr } %>"<% }
%><%== !$value ? ' selected="selected"' : '' =%>> No
    </label>
</div>

@@ yancy/form/bootstrap4/readonly.html.ep
<%  my $input = stash( 'input' );
    my $name = $input->{name};
    my $value = $input->{type} ne 'boolean' ? $input->{value}
              : $input->{value} ? 'Yes' : 'No';
%><p class="form-control-static<%= $input->{class} ? ' '.$input->{class} : '' %>"<%
%> data-name="<%= $name %>"><%= $value %></p>

@@ yancy/form/bootstrap4/field.html.ep
% my $field = stash( 'field' );
<div class="form-group">
    <label for="<%= $field->{id} %>"><%= $field->{title} || $field->{name} %><%=
        $field->{required} ? " *": "" %></label>
    <%= $field->{content} %><%
    if ( my $text = $field->{description} ) {
    =%><small class="form-text text-muted"><%= $text =%></small><% } =%>
</div>

@@ yancy/form/bootstrap4/form.html.ep
<% my $form = stash 'form'; my @attrs = qw( method action id );
%><form<%
for my $attr ( grep { defined $form->{ $_ } } @attrs ) {
%> <%= $attr %>="<%= $form->{$attr} %>" <% } =%>>
    <% if ( $form->{csrf} ) { %><%= csrf_field %><% } %>
    <% for my $field ( @{ $form->{fields} } ) { %><%= $field =%><% } =%>
    <button type="submit" class="btn btn-primary">Submit</button>
</form>
