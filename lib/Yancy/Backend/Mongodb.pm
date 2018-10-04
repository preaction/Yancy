package Yancy::Backend::Mongodb;
our $VERSION = '1.009';
# ABSTRACT: A backend for MongoDB

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'mongodb://localhost/mydb',
        collections => {
        },
    };

    ### MongoDB::Client object
    use Mojolicious::Lite;
    use MongoDB;
    plugin Yancy => {
        backend => {
            Mongodb => MongoDB->connect( 'mongodb://localhost' )->db( 'mydb' ),
        },
        collections => {
        },
    };

    ### Arrayref
    use Mojolicious::Lite;
    use My::Schema;
    plugin Yancy => {
        backend => {
            Mongodb => [
                'mongodb://localhost',
                'mydb',
            ],
        },
        collections => {
        },
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a L<MongoDB> server to
manage the data inside.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<< mongodb://<host>:<port>/<database> >>
where C<host> is the database host, C<port> is the port (defaults to 27017), and
C<database> is the database.

=head2 Collections

The collections for this backend are the names of the MongoDB collections in your
database.

=head1 SEE ALSO

L<Yancy::Backend>, L<MongoDB>, L<Yancy>

=cut

use Mojo::Base '-base';
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';
use Scalar::Util qw( looks_like_number blessed );
BEGIN {
    eval { require MongoDB; MongoDB->VERSION( 2.0 ); 1 }
        or die "Could not load Mongodb backend: MongoDB Perl driver version 2.0 or higher required\n";
}

has collections =>;
has db =>;

sub new {
    my ( $class, $backend, $collections ) = @_;
    if ( !ref $backend ) {
        my ( $dbname ) = $backend =~ m{^[^:]+://[^/]+/([^?]+)};
        $backend = MongoDB->connect( $dsn )->db( $dbname );
    }
    elsif ( !blessed $backend ) {
        my ( $connect_string, $dbname ) = @$backend;
        $backend = MongoDB->connect( $connect_string )->db( $dbname );
    }
    my %vars = (
        collections => $collections,
        db => $backend,
    );
    return $class->SUPER::new( %vars );
}

sub _id_field {
    my ( $self, $coll ) = @_;
    return $self->collections->{ $coll }{ 'x-id-field' } || '_id';
}

sub _coll {
    my ( $self, $coll ) = @_;
    return $self->db->collection( $coll );
}

sub create {
    my ( $self, $coll, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    my $result = $self->_coll( $coll )->insert_one( $params );
    return $params->{ $id_field } || $result->inserted_id;
}


sub get {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->db->find_one({ $id_field => $id });
}

# Parse a SQL::Abstract ORDER BY clause into something suitable for
# MongoDB
sub _order_by {
    my ( $self, $order_by ) = @_;
    if ( !ref $order_by ) {
        return { $order_by => 1 };
    }
}

my %mongo_opt_map = (
    limit       => 'limit',
    offset      => 'skip',
);

sub _mongo_opt {
    my ( $self, $opt ) = @_;
    for my $arg ( keys %mongo_opt_map ) {
        next unless $opt->{ $arg };
        $mongo_opt{ $mongo_opt_map{ $arg } } = $opt->{ $arg };
    }
    if ( my $order_by = _order_by( $opt->{order_by} ) ) {
        $mongo_opt{ sort } = $order_by;
    }
    return %mongo_opt;
}

sub list {
    my ( $self, $coll, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my %mongo_opt = _mongo_opt( $opt );
    my $cursor = $self->_coll( $coll )->find( $params, \%mongo_opt );
    return {
        items => $mysql->db->query( $query, @params )->hashes,
        total => $mysql->db->query( $total_query, @params )->hash->{total},
    };
}

sub set {
    my ( $self, $coll, $id, $params ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->_coll( $coll )
        ->replace_one({ $id_field => $id }, $params )->modified_count > 0;
}

sub delete {
    my ( $self, $coll, $id ) = @_;
    my $id_field = $self->_id_field( $coll );
    return $self->_coll( $coll )
        ->delete_one( { $id_field => $id } )->deleted_count > 0;
}

sub read_schema {
    die "Unimplemented\n";
}

1;
