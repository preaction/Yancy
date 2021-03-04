package Yancy;
our $VERSION = '1.070';
# ABSTRACT: The Best Web Framework Deserves the Best CMS

# "Mr. Fry: Son, your name is Yancy, just like me and my grandfather and
# so on. All the way back to minuteman Yancy Fry, who blasted commies in
# the American Revolution."

=encoding utf8

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin( Yancy => backend => 'postgresql://postgres@/mydb' );

    # Mojolicious::Lite
    plugin Yancy => backend => 'postgresql://postgres@/mydb'; # mysql, sqlite, dbic...

    # Secure access to the admin UI with Basic authentication
    my $under = $app->routes->under( '/yancy', sub( $c ) {
        return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
        $c->res->headers->www_authenticate('Basic');
        $c->render(text => 'Authentication required!', status => 401);
        return undef;
    });
    $self->plugin( Yancy => backend => 'postgresql://postgres@/mydb', route => $under );

    # ... then load the editor at http://127.0.0.1:3000/yancy

=head1 DESCRIPTION

=begin html

<div style="display: flex">
<div style="margin: 3px; flex: 1 1 50%">
<img alt="Screenshot of list of Futurama characters" src="https://raw.github.com/preaction/Yancy/master/eg/doc-site/public/screenshot.png?raw=true" style="max-width: 100%" width="600">
</div>
<div style="margin: 3px; flex: 1 1 50%">
<img alt="Screenshot of editing form for a person" src="https://raw.github.com/preaction/Yancy/master/eg/doc-site/public/screenshot-edit.png?raw=true" style="max-width: 100%" width="600">
</div>
</div>

=end html

L<Yancy> is a content management system (CMS) for L<Mojolicious>.  It
includes an admin application to edit content and tools to quickly build
an application.

=head2 Admin App

Yancy provides an application to edit content at the path C</yancy> on
your website. Yancy can manage data in multiple databases using
different L<backend modules|Yancy::Backend>. You can provide a URL
string to tell Yancy how to connect to your database, or you can provide
your database object.  Yancy supports the following databases:

=head3 Postgres

L<PostgreSQL|http://postgresql.org> is supported through the L<Mojo::Pg>
module.

    # PostgreSQL: A Mojo::Pg connection string
    plugin Yancy => backend => 'postgresql://postgres@/test';

    # PostgreSQL: A Mojo::Pg object
    plugin Yancy => backend => Mojo::Pg->new( 'postgresql://postgres@/test' );

=head3 MySQL

L<MySQL|http://mysql.com> is supported through the L<Mojo::mysql>
module.

    # MySQL: A Mojo::mysql connection string
    plugin Yancy => backend => 'mysql://user@/test';

    # MySQL: A Mojo::mysql object
    plugin Yancy => backend => Mojo::mysql->strict_mode( 'mysql://user@/test' );

=head3 SQLite

L<SQLite|http://sqlite.org> is supported through the L<Mojo::SQLite> module.
This is a good option if you want to try Yancy out.

    # SQLite: A Mojo::SQLite connection string
    plugin Yancy => backend => 'sqlite:test.db';

    # SQLite: A Mojo::SQLite object
    plugin Yancy => backend => Mojo::SQLite->new( 'sqlite::temp:' );

=head3 DBIx::Class

If you have a L<DBIx::Class> schema, Yancy can use it to edit the content.

    # DBIx::Class: A connection string
    plugin Yancy => backend => 'dbic://My::Schema/dbi:SQLite:test.db';

    # DBIx::Class: A DBIx::Class::Schema object
    plugin Yancy => backend => My::Schema->connect( 'dbi:SQLite:test.db' );

=head2 Content Tools

=head3 Schema Information and Validation

Yancy scans your database to determine what kind of data is inside, but
Yancy also accepts a L<JSON Schema|http://json-schema.org> to add more
information about your data. You can add descriptions, examples, and
other documentation that will appear in the admin application. You can
also add type, format, and other validation information, which Yancy
will use to validate input from users. See L<Yancy::Help::Config/Schema>
for how to define your schema.

    plugin Yancy => backend => 'postgres://postgres@/test',
        schema => {
            employees => {
                title => 'Employees',
                description => 'Our crack team of loyal dregs.',
                properties => {
                    address => {
                        description => 'Where to notify next-of-kin.',
                        # Regexp to validate this field
                        pattern => '^\d+ \S+',
                    },
                    email => {
                        # Use the browser's native e-mail input
                        format => 'email',
                    },
                },
            },
        };

=head3 Data Helpers

L<Mojolicious::Plugin::Yancy> provides helpers to work with your database content.
These use the validations provided in the schema to validate user input. These
helpers can be used in your route handlers to quickly add basic Create, Read, Update,
and Delete (CRUD) functionality. See L<Mojolicious::Plugin::Yancy/HELPERS> for a list
of provided helpers.

    # View a list of blog entries
    get '/' => sub( $c ) {
        my @blog_entries = $c->yancy->list(
            blog_entries =>
            { published => 1 },
            { order_by => { -desc => 'published_date' } },
        );
        $c->render(
            'blog_list',
            items => \@blog_entries,
        );
    };

    # View a single blog entry
    get '/blog/:blog_entry_id' => sub( $c ) {
        my $blog_entry = $c->yancy->get(
            blog_entries => $c->param( 'blog_entry_id' ),
        );
        $c->render(
            'blog_entry',
            item => $blog_entry,
        );
    };

=head3 Forms

The L<Yancy::Plugin::Form> plugin can generate input fields or entire
forms based on your schema information. The annotations in your schema
appear in the forms to help users fill them out. Additionally, with the
L<Yancy::Plugin::Form::Bootstrap4> module, Yancy can create forms using
L<Twitter Bootstrap|http://getbootstrap.com> components.

    # Load the form plugin
    app->yancy->plugin( 'Form::Bootstrap4' );

    # Edit a blog entry
    any [ 'GET', 'POST' ], '/edit/:blog_entry_id' => sub( $c ) {
        if ( $c->req->method eq 'GET' ) {
            my $blog_entry = $c->yancy->get(
                blog_entries => $c->param( 'blog_entry_id' ),
            );
            return $c->render(
                'blog_entry',
                item => $blog_entry,
            );
        }
        my $id = $c->param( 'blog_entry_id' );
        my $item = $c->req->params->to_hash;
        delete $item->{csrf_token}; # See https://docs.mojolicious.org/Mojolicious/Guides/Rendering#Cross-site-request-forgery
        $c->yancy->set( blog_entries => $id, $c->req->params->to_hash );
        $c->redirect_to( '/blog/' . $id );
    };

    __DATA__
    @@ blog_form.html.ep
    %= $c->yancy->form->form_for( 'blog_entries', item => stash 'item' )

=head3 Controllers

Yancy can add basic CRUD operations without writing the code yourself. The
L<Yancy::Controller::Yancy> module uses the schema information to show, search,
edit, create, and delete database items.

    # A rewrite of the routes above to use Yancy::Controller::Yancy

    # View a list of blog entries
    get '/' => {
        controller => 'yancy',
        action => 'list',
        schema => 'blog_entries',
        filter => { published => 1 },
        order_by => { -desc => 'published_date' },
    } => 'blog.list';

    # View a single blog entry
    get '/blog/:blog_entry_id' => {
        controller => 'yancy',
        action => 'get',
        schema => 'blog_entries',
    } => 'blog.get';

    # Load the form plugin
    app->yancy->plugin( 'Form::Bootstrap4' );

    # Edit a blog entry
    any [ 'GET', 'POST' ], '/edit/:blog_entry_id' => {
        controller => 'yancy',
        action => 'set',
        schema => 'blog_entries',
        template => 'blog_form',
        redirect_to => 'blog.get',
    } => 'blog.edit';

    __DATA__
    @@ blog_form.html.ep
    %= $c->yancy->form->form_for( 'blog_entries' )

=head3 Plugins

Yancy also has plugins for...

=over

=item * User authentication: L<Yancy::Plugin::Auth>

=item * File management: L<Yancy::Plugin::File>

=back

More development will be happening here soon!

=head1 GUIDES

For in-depth documentation on Yancy, see the following guides:

=over

=item * L<Yancy::Help::Config> - How to configure Yancy

=item * L<Yancy::Help::Cookbook> - How to cook various apps with Yancy

=item * L<Yancy::Help::Auth> - How to authenticate and authorize users

=item * L<Yancy::Help::Standalone> - How to use Yancy without a Mojolicious app

=item * L<Yancy::Help::Upgrading> - How to upgrade from previous versions

=back

=head1 OTHER RESOURCES

=head2 Example Applications

The L<Yancy Git repository on Github|http://github.com/preaction/Yancy>
includes some example applications you can use to help build your own
websites. L<View the example application directory|https://github.com/preaction/Yancy/tree/master/eg>.

=head1 BUNDLED PROJECTS

This project bundles some other projects with the following licenses:

=over

=item * L<jQuery|http://jquery.com> (version 3.2.1) Copyright JS Foundation and other contributors (MIT License)

=item * L<Bootstrap|http://getbootstrap.com> (version 4.3.1) Copyright 2011-2019 the Bootstrap Authors and Twitter, Inc. (MIT License)

=item * L<Popper.js|https://popper.js.org> (version 1.13.0) Copyright 2017 Federico Zivolo (MIT License)

=item * L<FontAwesome|http://fontawesome.io> (version 4.7.0) Copyright Dave Gandy (SIL OFL 1.1 and MIT License)

=item * L<Vue.js|http://vuejs.org> (version 2.5.3) Copyright 2013-2018, Yuxi (Evan) You (MIT License)

=item * L<marked|https://github.com/chjj/marked> (version 0.3.12) Copyright 2011-2018, Christopher Jeffrey (MIT License)

=back

The bundled versions of these modules may change. If you rely on these in your own app,
be sure to watch the changelog for version updates.

=head1 SEE ALSO

L<Mojolicious>

=cut

use Mojo::Base 'Mojolicious';
use Mojo::File qw( path );

# Default home should be the current working directory so that config,
# templates, and static files can be found.
has home => sub {
    return !$ENV{MOJO_HOME} ? path : $_[0]->SUPER::home;
};

sub startup {
    my ( $app ) = @_;
    unshift @{$app->plugins->namespaces}, 'Yancy::Plugin';

    $app->plugin( Config => { default => { } } );
    $app->plugin( 'Yancy', $app->config );

    $app->routes->get('/*fallback', { fallback => 'index' } )
    ->to( cb => sub {
        my ( $c ) = @_;
        my $path = $c->stash( 'fallback' );
        return if $c->render_maybe( $path );
        $path =~ s{(^|/)[^/]+$}{${1}index};
        return if $c->render_maybe( $path );
        return $c->reply->not_found;
    } );
    # Add default not_found renderer
    push @{$app->renderer->classes}, 'Yancy';
}

1;
__DATA__

@@ not_found.development.html.ep
% layout 'yancy';
<main id="app" class="container-fluid" style="margin-top: 10px">
    <div class="row">
        <div class="col-md-12">
            <h1>Welcome to Yancy</h1>
            <p>This is the default not found page.</p>

            <h2>Getting Started</h2>
            <p>To edit your data, go to <a href="/yancy">/yancy</a>.</p>
            <p>Add your templates to <tt><%= app->home->child( 'templates' ) %></tt>. Each template becomes a URL in your
            site:</p>
            <ul>
                <li><tt><%= app->home->child( 'templates', 'foo.html.ep' ) %></tt> becomes <a href="/foo">/foo</a>.</li>
                <li><tt><%= app->home->child( 'templates', 'foo', 'bar.html.ep' ) %></tt> becomes <a href="/foo/bar">/foo/bar</a>.</li>
            </ul>
            <p>To disable this page, run Yancy in production mode with <kbd>-m production</kbd>.</p>
        </div>
    </div>
</main>

