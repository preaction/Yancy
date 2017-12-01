package Yancy::Backend::Dbic;
our $VERSION = '0.001';
# ABSTRACT: A backend for DBIx::Class schemas

=head1 SYNOPSIS

    # yancy.conf
    {
        backend => 'dbic://My::Schema/dbi:Pg:localhost',
        collections => {
            ResultSet => { ... },
        },
    }

    # Plugin
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'dbic://My::Schema/dbi:Pg:localhost',
        collections => {
            ResultSet => { ... },
        },
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a L<DBIx::Class> schema to manage
the data inside.

=head2 Backend URL

The URL for this backend takes the form C<< dbic://<schema_class>/<dbi_dsn> >>
where C<schema_class> is the DBIx::Class schema module name and C<dbi_dsn> is
the full L<DBI> data source name (DSN) used to connect to the database.

=head2 Collections

The collections for this backend are the names of the
L<DBIx::Class::Row> classes in your schema, just as DBIx::Class allows
in the C<< $schema->resultset >> method.

So, if you have the following schema:

    package My::Schema;
    use base 'DBIx::Class::Schema';
    __PACKAGE__->load_namespaces;

    package My::Schema::Result::People;
    __PACKAGE__->table( 'people' );
    __PACKAGE__->add_columns( qw/ id name email / );

    package My::Schema::Result::Business
    __PACKAGE__->table( 'business' );
    __PACKAGE__->add_columns( qw/ id name email / );

You could map that schema to the following collections:

    {
        backend => 'dbic://My::Schema/dbi:SQLite:test.db',
        collections => {
            People => {
                properties => {
                    id => { type => 'integer' },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
            Business => {
                properties => {
                    id => { type => 'integer' },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
        },
    }

=head1 SEE ALSO

L<DBIx::Class>, L<Yancy>

=cut

use v5.24;
use Mojo::Base 'Mojo';
use experimental qw( signatures postderef );
use Scalar::Util qw( looks_like_number );
use Module::Runtime qw( use_module );

has collections => ;
has dbic =>;

sub new( $class, $url, $collections ) {
    my ( $dbic_class, $dsn, $optstr ) = $url =~ m{^[^:]+://([^/]+)/([^?]+)(?:\?(.+))?$};
    my %vars = (
        collections => $collections,
        dbic => use_module( $dbic_class )->connect( $dsn ),
    );
    return $class->SUPER::new( %vars );
}

sub _rs( $self, $coll, $opt={} ) {
    my $rs = $self->dbic->resultset( $coll )->search( {}, $opt );
    $rs->result_class( 'DBIx::Class::ResultClass::HashRefInflator' );
    return $rs;
}

sub create( $self, $coll, $params ) {
    my $created = $self->dbic->resultset( $coll )->create( $params );
    return { $created->get_columns };
}

sub get( $self, $coll, $id ) {
    return $self->_rs( $coll )->find( $id );
}

sub list( $self, $coll, $params={}, $opt={} ) {
    my %rs_opt;
    if ( $opt->{limit} ) {
        die "Limit must be number" if !looks_like_number $opt->{limit};
        $rs_opt{ rows } = $opt->{limit};
    }
    if ( $opt->{offset} ) {
        die "Offset must be number" if !looks_like_number $opt->{offset};
        $rs_opt{ offset } = $opt->{offset};
    }
    my $rs = $self->_rs( $coll, \%rs_opt );
    return { rows => [ $rs->all ], total => $self->_rs( $coll )->count };
}

sub set( $self, $coll, $id, $params ) {
    return $self->dbic->resultset( $coll )->find( $id )->set_columns( $params )->update;
}

sub delete( $self, $coll, $id ) {
    $self->dbic->resultset( $coll )->find( $id )->delete;
}

1;
