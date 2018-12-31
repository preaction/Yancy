package Yancy;
our $VERSION = '1.020';
# ABSTRACT: A simple framework and editor for content-driven Mojolicious websites

=head1 SYNOPSIS

    use Mojolicious::Lite;
    use Mojo::Pg; # Supported backends: Pg, MySQL, SQLite, DBIx::Class
    plugin Yancy => {
        backend => { Pg => Mojo::Pg->new( 'postgres:///myapp' ) },
        read_schema => 1,
    };

=head1 DESCRIPTION

=begin html

<p>
  <img alt="Screenshot of list of Futurama characters"
    src="https://raw.github.com/preaction/Yancy/master/eg/screenshot.png?raw=true"
    width="600px">
  <img alt="Screenshot of editing form for a person"
    src="https://raw.github.com/preaction/Yancy/master/eg/screenshot-edit.png?raw=true"
    width="600px">
</p>

=end html

L<Yancy> is a simple content management system (CMS) for administering
content in a database. Yancy accepts a configuration file that describes
the data in the database and builds a website that lists all of the
available data and allows a user to edit data, delete data, and add new
data.

Yancy uses L<JSON Schema|http://json-schema.org> to define the data in
the database. The schema is added to an L<OpenAPI
specification|http://openapis.org> which creates a L<REST
API|https://en.wikipedia.org/wiki/Representational_state_transfer> for
your data.

Yancy can be run in a standalone mode (which can be placed behind
a proxy), or can be embedded as a plugin into any application that uses
the L<Mojolicious> web framework.

Yancy can manage data in multiple databases using different backends
(L<Yancy::Backend> modules). Backends exist for L<Postgres via
Mojo::Pg|Yancy::Backend::Pg>, L<MySQL via
Mojo::mysql|Yancy::Backend::Mysql>, L<SQLite via
Mojo::SQLite|Yancy::Backend::Sqlite>, and L<DBIx::Class, a Perl
ORM|Yancy::Backend::Dbic>

=head2 Mojolicious Plugin

Yancy is primarily a Mojolicious plugin to ease development and
management of Mojolicious applications. Yancy provides:

=over

=item *

L<Controllers|Yancy::Controller::Yancy> which you can use to easily
L<list data|Yancy::Controller::Yancy/list>, L<display
data|Yancy::Controller::Yancy/get>, L<modify
data|Yancy::Controller::Yancy/set>, and L<delete
data|Yancy::Controller::Yancy/delete>.

=item *

L<Helpers|Mojolicious::Plugin::Yancy/HELPERS> to access data, validate
forms

=item *

L<Templates|Mojolicious::Plugin::Yancy/TEMPLATES> which you can override
to customize the Yancy editor's appearance

=back

For information on how to use Yancy as a Mojolicious plugin, see
L<Mojolicious::Plugin::Yancy>.

=head2 Example Applications

The L<Yancy Git repository on Github|http://github.com/preaction/Yancy>
includes some example applications you can use to help build your own
websites. L<View the example application directory|https://github.com/preaction/Yancy/tree/master/eg>.

=head2 Yancy Plugins

Yancy comes with plugins to enhance your website.

=over

=item *

L<The Auth::Basic plugin|Yancy::Plugin::Auth::Basic> provides a simple,
password-based authentication system for the Yancy editor and your
website.

=item *

L<The Form plugin|Yancy::Plugin::Form> can generate forms for the
configured collections, or for individual fields. There are included
form generators for L<Bootstrap 4|Yancy::Plugin::Form::Bootstrap4>.

=back

More development will be happening here soon!

=head2 Standalone App

Yancy can also be run as a standalone app in the event one wants to
develop applications solely using Mojolicious templates. For
information on how to run Yancy as a standalone application, see
L<Yancy::Help::Standalone>.

=head2 REST API

This application creates a REST API using the standard
L<OpenAPI|http://openapis.org> API specification. The API spec document
is located at C</yancy/api>.

=head1 CONFIGURATION

See L<Yancy::Help::Config> for how to configure Yancy in both plugin and
standalone mode.

=head1 BUNDLED PROJECTS

This project bundles some other projects with the following licenses:

=over

=item * L<jQuery|http://jquery.com> (version 3.2.1) Copyright JS Foundation and other contributors (MIT License)

=item * L<Bootstrap|http://getbootstrap.com> (version 4.0.0) Copyright 2011-2017 the Bootstrap Authors and Twitter, Inc. (MIT License)

=item * L<Popper.js|https://popper.js.org> (version 1.13.0) Copyright 2017 Federico Zivolo (MIT License)

=item * L<FontAwesome|http://fontawesome.io> (version 4.7.0) Copyright Dave Gandy (SIL OFL 1.1 and MIT License)

=item * L<Vue.js|http://vuejs.org> (version 2.5.3) Copyright 2013-2018, Yuxi (Evan) You (MIT License)

=item * L<marked|https://github.com/chjj/marked> (version 0.3.12) Copyright 2011-2018, Christopher Jeffrey (MIT License)

=back

The bundled versions of these modules may change. If you rely on these in your own app,
be sure to watch the changelog for version updates.

=head1 SEE ALSO

L<JSON schema|http://json-schema.org>, L<Mojolicious>

=cut

use Mojo::Base 'Mojolicious';

sub startup {
    my ( $app ) = @_;
    $app->plugin( Config => { default => { } } );
    $app->plugin( 'Yancy', $app->config );

    unshift @{$app->plugins->namespaces}, 'Yancy::Plugin';
    for my $plugin ( @{ $app->config->{plugins} } ) {
        $app->plugin( @$plugin );
    }

    $app->routes->get('/*path', { path => 'index' } )
    ->to( cb => sub {
        my ( $c ) = @_;
        my $path = $c->stash( 'path' );
        return if $c->render_maybe( $path );
        $path =~ s{(^|/)[^/]+$}{${1}index};
        return $c->render( $path );
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

