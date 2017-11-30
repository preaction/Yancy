package Yancy;
our $VERSION = '0.001';
# ABSTRACT: A simple CMS for administrating data

=head1 SYNOPSIS

    ### Standalone app
    $ yancy daemon

    ### Mojolicious plugin
    use Mojolicious::Lite;
    plugin Yancy => { ... };

=head1 DESCRIPTION

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
Mojo::mysql|Yancy::Backend::Mysql>, and L<DBIx::Class, a Perl
ORM|Yancy::Backend::DBIC>

=head2 Standalone App

To run Yancy as a standalone application, you must create a C<yancy.conf>
configuration file that defines how to connect to your database and what
the data inside looks like. See L</CONFIGURATION> for details.

B<NOTE:> Yancy does not have authentication or authorization built-in.
If you want to control which users have access to data, you should use
an HTTP proxy with these features.

=head2 Mojolicious Plugin

For information on how to use Yancy as a Mojolicious plugin, see
L<Mojolicious::Plugin::Yancy>.

=head2 REST API

This application creates a REST API using the standard
L<OpenAPI|http://openapis.org> API specification. The API spec document
is located at C</api> in the standalone app, and C</yancy/api> in the
Mojolicious plugin.

=head1 CONFIGURATION

The Yancy configuration file is a Perl data structure. The individual
parts are described below. An example configuration file looks like:

    {
        backend => 'pg://user@example.com/mydb',
        collections => {
            people => {
                type => 'object',
                properties => {
                    id => { type => 'integer' },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
        },
    }

=head2 Database Backend

The C<backend> URL defines what database to use and how to connect to
it. Each backend has its own format of URL, and some examples are shown
below. See your backend's documentation for more information.

=over

=item L<Postgres backend|Yancy::Backend::Pg>

    backend => 'pg://user@example.com/mydb',

=item L<MySQL backend|Yancy::Backend::Mysql>

    backend => 'mysql://user@localhost/mydb',

=item L<DBIx::Class backend|Yancy::Backend::Dbic>

    backend => 'dbic://My::Schema/dbi:SQLite:file.db',

=back

=head2 Data Collections

The C<collections> data structure defines what data is in the database.
Each key in this structure refers to the name of a collection, and the
value describe the fields for items inside the collection.

Each backend may define a collection differently. For a relational
database like Postgres or MySQL, a collection is a table, and the fields
are columns. For an ORM like DBIx::Class, the collections are ResultSet
objects. For a document store like MongoDB, the collections are
collections. See your backend's documentation for more information.

Collections are configured using L<JSON Schema|http://json-schema.org>.
The JSON Schema defines what fields (properties) an item has, and what
type of data those field have. The JSON Schema also can define
constraints like required fields or validate strings with regular
expressions. The schema can also contain metadata like a C<title>,
C<description>, and even an C<example> value. For more information on
what can be defined, see L<the docs on JSON Schema|http://json-schema.org>.

For a collection named C<people> that has 3 fields (an integer C<id> and
two strings, C<name> and C<email>), a minimal JSON schema will look like
this:

    collections => {
        people => {
            properties => {
                id => {
                    type => 'integer',
                },
                name => {
                    type => 'string',
                },
                email => {
                    type => 'string',
                },
            },
        },
    },

=head3 Example Values

Setting an example value makes it easier to add new data. When a user
tries to add a new item, Yancy will fill in the data from the C<example>
key of the collection. This key holds an example object using fake data.
As an example of our C<people> collection:

    people => {
        example => {
            name => 'Philip J. Fry',
            email => 'fry@aol.com',
        },
        properties => { ... },
    },

=head3 Extended Collection Configuration

There are some extended fields you can add to your collection definition
to control how it is treated by Yancy.

=over

=item x-id-field

This key sets the name of the collection's ID field to use to uniquely
identify individual items. By default, Yancy assumes the ID field is
named C<id>. If your collection uses some other identifier (e-mail
address or username for example), you should set this configuration key.

    people => {
        'x-id-field' => 'email',
        properties => { ... },
    },

=item x-list-columns

This key should be an array of columns to display on the list view, in
order. This helps put useful information on the list page.

    people => {
        'x-list-columns' => [ 'name', 'email' ],
        properties => { ... },
    },

=back

=head1 SEE ALSO

L<JSON schema|http://json-schema.org>, L<Mojolicious>

=cut

use v5.24;
use Mojo::Base 'Mojolicious';
use experimental qw( signatures postderef );

sub startup( $app ) {
    $app->plugin( Config => { default => { } } );
    $app->plugin( 'Yancy', {
        %{ $app->config },
        route => $app->routes->any('/'),
    } );
}

1;
