package Yancy::Backend::Mysql;
our $VERSION = '1.078';
# ABSTRACT: A backend for MySQL using Mojo::mysql

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'mysql:///mydb',
        read_schema => 1,
    };

    ### Mojo::mysql object
    use Mojolicious::Lite;
    use Mojo::mysql;
    plugin Yancy => {
        backend => { Mysql => Mojo::mysql->new( 'mysql:///mydb' ) },
        read_schema => 1,
    };

    ### Hash reference
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => {
            Mysql => {
                dsn => 'dbi:mysql:dbname',
                username => 'fry',
                password => 'b3nd3r1sgr34t',
            },
        },
        read_schema => 1,
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a MySQL database to manage
the data inside. This backend uses L<Mojo::mysql> to connect to MySQL.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<<
mysql://<user>:<pass>@<host>:<port>/<db> >>.

Some examples:

    # Just a DB
    mysql:///mydb

    # User+DB (server on localhost:3306)
    mysql://user@/mydb

    # User+Pass Host and DB
    mysql://user:pass@example.com/mydb

=head2 Schema Names

The schema names for this backend are the names of the tables in the
database.

So, if you have the following schema:

    CREATE TABLE people (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL
    );
    CREATE TABLE business (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NULL
    );

You could map that to the following schema:

    {
        backend => 'mysql://user@/mydb',
        schema => {
            People => {
                required => [ 'name', 'email' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
            Business => {
                required => [ 'name' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
        },
    }

=head1 SEE ALSO

L<Mojo::mysql>, L<Yancy>

=cut

use Mojo::Base 'Yancy::Backend::MojoDB';
use Scalar::Util qw( blessed );
use Yancy::Util qw( is_type is_format );
BEGIN {
    eval { require Mojo::mysql; Mojo::mysql->VERSION( 1.05 ); 1 }
        or die "Could not load Mysql backend: Mojo::mysql version 1.05 or higher required\n";
}

sub new {
    my ( $class, $driver, $schema ) = @_;
    if ( blessed $driver ) {
        die "Need a Mojo::mysql object. Got " . blessed( $driver )
            if !$driver->isa( 'Mojo::mysql' );
        return $class->SUPER::new( $driver, $schema );
    }
    elsif ( ref $driver eq 'HASH' ) {
        return $class->SUPER::new( Mojo::mysql->new( $driver ), $schema );
    }
    my $found = (my $connect = $driver) =~ s{^.*?:}{};
    return $class->SUPER::new(
        Mojo::mysql->new( $found ? "mysql:$connect" : () ),
        $schema,
    );
}

sub table_info {
    my ( $self ) = @_;
    my $dbh = $self->dbh;
    my $schema = $self->driver->db->query( 'SELECT database()' )->array->[0];
    return $dbh->table_info( undef, $schema, '%', undef )->fetchall_arrayref({});
}

sub fixup_default {
    my ( $self, $value ) = @_;
    return undef if !defined $value;
    return "now" if $value =~ /^(?:NOW|(?:CUR(?:RENT_)?|LOCAL|UTC_)(?:DATE|TIME(?:STAMP)?))(?:\(\))?/i;
    $value;
}

sub normalize {
    my ( $self, $schema_name, $data ) = @_;
    $data = $self->SUPER::normalize( $schema_name, $data ) || return undef;
    my $schema = $self->schema->{ $schema_name };
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my %props = %{
        $schema->{properties} || $self->schema->{ $real_schema_name }{properties}
    };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my $prop = $props{ $key } || next;
        my ( $type, $format ) = @{ $prop }{qw( type format )};
        if ( is_type( $type, 'string' ) && is_format( $format, 'date-time' ) ) {
            if ( !$data->{ $key } ) {
                $replace{ $key } = undef;
            }
            elsif ( $data->{ $key } eq 'now' ) {
                $replace{ $key } = \'NOW()';
            }
        }
    }
    return { %$data, %replace };
}

sub column_info {
    my ( $self, $table ) = @_;
    my $columns = $self->dbh->column_info( @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )}, '%' )->fetchall_arrayref({});
    for my $c ( @$columns ) {
        if ( $c->{mysql_values} ) {
            $c->{ENUM} = $c->{mysql_values};
        }
        if ( $c->{mysql_is_auto_increment} ) {
            $c->{AUTO_INCREMENT} = 1;
        }
        $c->{COLUMN_DEF} = $self->fixup_default( $c->{COLUMN_DEF} );
    }
    return $columns;
}

1;
