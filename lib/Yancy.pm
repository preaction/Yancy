package Yancy;
our $VERSION = '1.076';
# ABSTRACT: The Best Web Framework Deserves the Best CMS

# "Mr. Fry: Son, your name is Yancy, just like me and my grandfather and
# so on. All the way back to minuteman Yancy Fry, who blasted commies in
# the American Revolution."

=encoding utf8

=head1 DESCRIPTION

Yancy is a simple content management system (CMS) for the L<Mojolicious> web framework.

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

Get started with L<the Yancy documentation|Yancy::Guides>!

This file documents the application base class. You can use this class directly
via the C<yancy> command, or you can extend this class to build your own app.

=head1 Starting Your Own Yancy Application

If you have an existing L<Mojolicious> application you want to add Yancy
to, see L<Mojolicious::Plugin::Yancy>.

The base Yancy class exists to provide a way to rapidly prototype a data-driven
web application. Apps that inherit from Yancy get these features out-of-the-box:

=over

=item * The Yancy CMS (L<Mojolicious::Plugin::Yancy>)

=item * Database editor (L<Yancy::Plugin::Editor>)

=item * User logins (L<Yancy::Plugin::Auth>)

=item * Role-based access controls (L<Yancy::Plugin::Roles>)

=back

If you're familiar with developing Mojolicious applications, you can start
from the app skeleton at L<https://github.com/preaction/Yancy/tree/master/eg/skeleton>.

=for comment XXX: Create `yancy generate app` and `yancy generate lite-app` commands

To begin writing a new application from scratch, create a C<lib>
directory and add a C<MyApp.pm> file that extends the C<Yancy> class:

    package MyApp;
    use Mojo::Base 'Yancy', -signatures;

As in any other L<Mojolicious> app, add your routes, plugins, and other setup to
the C<startup> method. Don't forget to call Yancy's L</startup> method!

    sub startup( $self ) {
        $self->SUPER::startup;
        # ... Add your routes and other setup here
    }

Next, create a configuration file named C<my_app.conf> to connect to your database:

    {
        backend => 'sqlite:my_app.db',
    }

Last, create a L<simple application script|https://docs.mojolicious.org/Mojolicious/Guides/Growing#Simplified-application-script>
named C<script/my_app> to start your application:

    #!/usr/bin/env perl

    use Mojo::Base -strict;
    use lib qw(lib);
    use Mojolicious::Commands;

    # Start command line interface for application
    Mojolicious::Commands->start_app('MyApp');

Now you can run C<./script/my_app daemon> to start your app!

To make developing your app easy and fun, make sure you're familiar with
these guides:

=over

=item L<The Mojolicious tutorial and guides|https://docs.mojolicious.org>

=item L<The Yancy tutorial|Yancy::Guides::Tutorial>

=item L<The Yancy guides|Yancy::Guides>

=back

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
use Mojo::Loader qw( data_section );

# Default home should be the current working directory so that config,
# templates, and static files can be found.
has home => sub {
    return !$ENV{MOJO_HOME} ? path : $_[0]->SUPER::home;
};

sub startup {
    my ( $app ) = @_;
    unshift @{$app->plugins->namespaces}, 'Yancy::Plugin';

    if ( !keys %{ $app->config } ) {
        $app->plugin( Config => { } );
    }
    $app->plugin( 'Yancy', $app->config );

    # XXX: Add default migrations
    # Set up default auth plugin if no auth found yet
    if ( !$app->yancy->can( 'auth' ) ) {
        # Update schema if needed
        # XXX: Add named migration support to backends. Migration should
        # trigger a re-read of the schema.
        my ( $backend_type ) = ( lc ref $app->yancy->backend ) =~ m{::([^:]+)$};
        if ( my $sql = data_section __PACKAGE__, "migrations.yancy_logins.$backend_type.sql" ) {
            my $migrations = (ref $app->yancy->backend->driver->migrations)->new( $backend_type => $app->yancy->backend->driver );
            $migrations->name( 'yancy_logins' )->from_string( $sql )->migrate;
            for my $table ( qw( yancy_logins yancy_login_roles ) ) {
                my $schema = $app->yancy->backend->read_schema( $table );
                $app->yancy->schema( $table => $schema );
            }
        }

        $app->plugin( Auth => {
            schema => 'yancy_logins',
            username_field => 'login_name',
            plugins => [
                [
                    Password => {
                        password_field => 'password',
                        password_digest => { type => 'SHA-1' },
                    },
                ],
            ],
        } );

        # XXX: Create a "Setup" plugin to initialize an admin login if
        # no logins exist
    }

    $app->plugin( Roles => {
        schema => 'yancy_login_roles',
        userid_field => 'login_id',
        role_field => 'role',
    } );

    # Add default not_found renderer
    push @{$app->renderer->classes}, 'Yancy';
}

1;
__DATA__

@@ migrations.yancy_logins.mysql.sql
-- 1 up
CREATE TABLE yancy_logins (
    login_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    login_name VARCHAR(191) NOT NULL UNIQUE,
    password VARCHAR(191) NOT NULL
);
CREATE TABLE yancy_login_roles (
    login_id BIGINT NOT NULL,
    role VARCHAR(191) NOT NULL,
    PRIMARY KEY ( login_id, role )
);
-- 1 down
DROP TABLE yancy_logins;
DROP TABLE yancy_login_roles;

@@ migrations.yancy_logins.sqlite.sql
-- 1 up
CREATE TABLE yancy_logins (
    login_id INTEGER PRIMARY KEY AUTOINCREMENT,
    login_name VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);
CREATE TABLE yancy_login_roles (
    login_id INTEGER NOT NULL,
    role VARCHAR(255) NOT NULL,
    PRIMARY KEY ( login_id, role )
);
-- 1 down
DROP TABLE yancy_logins;
DROP TABLE yancy_login_roles;

@@ migrations.yancy_logins.pg.sql
-- 1 up
CREATE TABLE yancy_logins (
    login_id SERIAL PRIMARY KEY,
    login_name VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);
CREATE TABLE yancy_login_roles (
    login_id INTEGER NOT NULL,
    role VARCHAR(255) NOT NULL,
    PRIMARY KEY ( login_id, role )
);
-- 1 down
DROP TABLE yancy_logins;
DROP TABLE yancy_login_roles;

@@ not_found.development.html.ep
% layout 'yancy';
<main id="app" class="container-fluid" style="margin-top: 10px">
    <div class="row">
        <div class="col-md-12">
            <h1>Welcome to Yancy</h1>
            <p>This is the default not found page.</p>

            <h2>Getting Started</h2>
            <p>To edit your data, go to <a href="/yancy">/yancy</a>.</p>
            <p>For more information, visit these sites:</p>
            <ul>
                <li><a href="http://preaction.me/yancy/perldoc">Yancy Documentation</a></li>
                <li><a href="http://docs.mojolicious.org">Mojolicious Documentation</a></li>
            </ul>
            <p>To disable this page, run Yancy in production mode with <kbd>-m production</kbd>.</p>
        </div>
    </div>
</main>

