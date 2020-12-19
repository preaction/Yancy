package Yancy::Backend::Dbic;
our $VERSION = '1.069';
# ABSTRACT: A backend for DBIx::Class schemas

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'dbic://My::Schema/dbi:Pg:localhost',
        read_schema => 1,
    };

    ### DBIx::Class::Schema object
    use Mojolicious::Lite;
    use My::Schema;
    plugin Yancy => {
        backend => { Dbic => My::Schema->connect( 'dbi:SQLite:myapp.db' ) },
        read_schema => 1,
    };

    ### Arrayref
    use Mojolicious::Lite;
    use My::Schema;
    plugin Yancy => {
        backend => {
            Dbic => [
                'My::Schema',
                'dbi:SQLite:mysql.db',
                undef, undef,
                { PrintError => 1 },
            ],
        },
        read_schema => 1,
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a L<DBIx::Class> schema to
manage the data inside.

=head1 METHODS

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 read_schema

While reading the various sources, this method will check each source's
C<result_class> for the existence of a C<yancy> method. If it exists,
that will be called, and must return the initial JSON schema for Yancy.

A very useful possibility is for that JSON schema to just contain
C<<{ 'x-ignore' => 1 }>>.

=head2 Backend URL

The URL for this backend takes the form C<< dbic://<schema_class>/<dbi_dsn> >>
where C<schema_class> is the DBIx::Class schema module name and C<dbi_dsn> is
the full L<DBI> data source name (DSN) used to connect to the database.

=head2 Schema Names

The schema names for this backend are the names of the
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

You could map that to the following schema names:

    {
        backend => 'dbic://My::Schema/dbi:SQLite:test.db',
        schema => {
            People => {
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

L<Yancy::Backend>, L<DBIx::Class>, L<Yancy>

=cut

use Mojo::Base '-base';
use Role::Tiny qw( with );
with 'Yancy::Backend::Role::Sync';
use Scalar::Util qw( looks_like_number blessed );
use Mojo::Loader qw( load_class );
use Mojo::JSON qw( true encode_json );
require Yancy::Backend::Role::Relational;

has schema =>;
sub collections {
    require Carp;
    Carp::carp( '"collections" method is now "schema"' );
    shift->schema( @_ );
}

has dbic =>;

*_normalize = \&Yancy::Backend::Role::Relational::normalize;

sub new {
    my ( $class, $backend, $schema ) = @_;
    if ( !ref $backend ) {
        my ( $dbic_class, $dsn, $optstr ) = $backend =~ m{^[^:]+://([^/]+)/([^?]+)(?:\?(.+))?$};
        if ( my $e = load_class( $dbic_class ) ) {
            die ref $e ? "Could not load class $dbic_class: $e" : "Could not find class $dbic_class";
        }
        $backend = $dbic_class->connect( $dsn, undef, undef, {}, { quote_names => 1 } );
    }
    elsif ( !blessed $backend ) {
        my $dbic_class = shift @$backend;
        if ( my $e = load_class( $dbic_class ) ) {
            die ref $e ? "Could not load class $dbic_class: $e" : "Could not find class $dbic_class";
        }
        if ( my $extra_attrs = $backend->[4] ||= {} ) {
            $extra_attrs->{ quote_names } = 1;
        }
        $backend = $dbic_class->connect( @$backend );
    }
    my %vars = (
        schema => $schema,
        dbic => $backend,
    );
    return $class->SUPER::new( %vars );
}

sub _rs {
    my ( $self, $schema_name, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $schema = $self->schema->{ $schema_name };
    my $real_schema = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $rs = $self->dbic->resultset( $real_schema )->search( $params, $opt );
    $rs->result_class( 'DBIx::Class::ResultClass::HashRefInflator' );
    return $rs;
}

sub _find {
    my ( $self, $schema_name, $id ) = @_;
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    my %id;
    if ( ref $id_field eq 'ARRAY' ) {
        %id = %$id;
        die "Missing composite ID parts" if @$id_field > keys %$id;
    }
    else {
        %id = ( $id_field => $id );
    }
    return $self->dbic->resultset( $schema_name )->find( \%id );
}

sub create {
    my ( $self, $schema_name, $params ) = @_;
    $params = $self->_normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name': " . encode_json $params
        if grep ref && ref ne 'SCALAR', values %$params;
    my $created = $self->dbic->resultset( $schema_name )->create( $params );
    my $id_field = $self->schema->{ $schema_name }{ 'x-id-field' } || 'id';
    return ref $id_field eq 'ARRAY'
        ? { map { $_ => $created->$_ } @$id_field }
        : $created->$id_field
        ;
}

sub get {
    my ( $self, $schema_name, $id ) = @_;
    my $schema = $self->schema->{ $schema_name };
    my $real_schema = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_schema }{properties};
    my $id_field = $schema->{ 'x-id-field' } || 'id';
    my %id;
    if ( ref $id_field eq 'ARRAY' ) {
        %id = %$id;
        die "Missing composite ID parts" if @$id_field > keys %$id;
    }
    else {
        %id = ( $id_field => $id );
    }
    my $ret = $self->_rs(
        $real_schema,
        undef,
        { select => [ keys %$props ] },
    )->find( \%id );
    return $self->_normalize( $schema_name, $ret );
}

sub list {
    my ( $self, $schema_name, $params, $opt ) = @_;
    $params ||= {}; $opt ||= {};
    my $schema = $self->schema->{ $schema_name };
    my $real_schema = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my $props = $schema->{properties}
        || $self->schema->{ $real_schema }{properties};
    my %rs_opt = (
        order_by => $opt->{order_by},
        select => [ keys %$props ],
    );
    if ( $opt->{limit} ) {
        die "Limit must be number" if !looks_like_number $opt->{limit};
        $rs_opt{ rows } = $opt->{limit};
    }
    if ( $opt->{offset} ) {
        die "Offset must be number" if !looks_like_number $opt->{offset};
        $rs_opt{ offset } = $opt->{offset};
    }
    my $rs = $self->_rs( $schema_name, $params, \%rs_opt );
    return {
        items => [ map $self->_normalize( $schema_name, $_ ), $rs->all ],
        total => $self->_rs( $schema_name, $params )->count,
    };
}

sub set {
    my ( $self, $schema_name, $id, $params ) = @_;
    $params = $self->_normalize( $schema_name, $params );
    die "No refs allowed in '$schema_name'($id): " . encode_json $params
        if grep ref && ref ne 'SCALAR', values %$params;
    if ( my $row = $self->_find( $schema_name, $id ) ) {
        $row->set_columns( $params );
        if ( $row->is_changed ) {
            $row->update;
            return 1;
        }
    }
    return 0;
}

sub delete {
    my ( $self, $schema_name, $id ) = @_;
    # We assume that if we can find the row by ID, that the delete will
    # succeed
    if ( my $row = $self->_find( $schema_name, $id ) ) {
        $row->delete;
        return 1;
    }
    return 0;
}

my %fix_default = (
    current_timestamp => "now",
    current_time => "now",
    current_date => "now",
);

sub read_schema {
    my ( $self, @schema_names ) = @_;
    my %schema;

    my @schemas = @schema_names ? @schema_names : $self->dbic->sources;
    my %classes;
    for my $schema_name ( @schemas ) {
        # ; say "Got schema $schema_name";
        my $source = $self->dbic->source( $schema_name );
        my $result_class = $source->result_class;
        # ; say "Adding class: $result_class ($schema_name)";
        $classes{ $result_class } = $source;
        $schema{ $schema_name } = $result_class->yancy if $result_class->can('yancy');
        $schema{ $schema_name }{type} = 'object';
        my @columns = $source->columns;
        for my $i ( 0..$#columns ) {
            my $column = $columns[ $i ];
            my $c = $source->column_info( $column );
            # ; use Data::Dumper;
            # ; say Dumper $c;
            my $is_auto = $c->{is_auto_increment};
            my $default = ref $c->{default_value} eq 'SCALAR'
                ? ${ $c->{default_value} }
                : $c->{default_value };
            $schema{ $schema_name }{ properties }{ $column } = {
                $self->_map_type( $c ),
                $is_auto ? ( readOnly => true ) : (),
                defined $default ? (
                    default => exists $fix_default{ $default }
                        ? $fix_default{ $default }
                        : $default
                ) : (),
                'x-order' => $i + 1,
            };
            if ( !$c->{is_nullable} && !$is_auto && !defined $c->{default_value} ) {
                push @{ $schema{ $schema_name }{ required } }, $column;
            }
        }

        my %is_pk = map {$_=>1} $source->primary_columns;
        my @unique_columns =
            grep !$is_pk{$_}, # we know about those already
            map @$_, grep scalar( @$_ ) == 1,
            map [ $source->unique_constraint_columns( $_ ) ],
            $source->unique_constraint_names;
        my ( $pk ) = keys %is_pk;
        if ( @unique_columns == 1 and $unique_columns[0] ne 'id' ) {
            # favour "natural" key over "surrogate" integer one, if exists
            $schema{ $schema_name }{ 'x-id-field' } = $unique_columns[0];
        }
        elsif ( $pk && $pk ne 'id' ) {
            $schema{ $schema_name }{ 'x-id-field' } = $pk;
        }

    }

    # Link foreign keys
    for my $source ( values %classes ) {
        for my $rel_name ( $source->relationships ) {
            my $rel = $source->relationship_info( $rel_name );
            next unless $rel->{attrs}{accessor} eq 'single'; # Only belongs_to
            # ; use Data::Dumper;
            # ; say Dumper $rel;
            my $self_schema = $source->source_name;
            my $foreign_class = $rel->{source};
            # XXX Only very simple joins are possible here right now
            my @self_cols = map /^[^.]+\.(.+)$/, grep /^self[.]/, %{ $rel->{cond} };
            my @foreign_cols = map /^[^.]+\.(.+)$/, grep /^foreign[.]/, %{ $rel->{cond} };
            if ( @self_cols > 1 || @foreign_cols > 1 ) {
                warn sprintf
                    'Cannot do foreign key with multiple columns yet on table %s, relationship %s',
                    $source->source_name, $rel_name,
                    ;
                next;
            }
            # ; say "Looking for foreign class: $foreign_class";
            next unless $classes{ $foreign_class };
            my $foreign_schema = $classes{ $foreign_class }->source_name;
            my $foreign_id = $schema{ $foreign_schema }{'x-id-field'} // 'id';
            if ( $foreign_cols[0] ne $foreign_id ) {
                warn sprintf
                    'Cannot do foreign key with columns that are not the primary ID (x-id-field) on table %s, relationship %s (foreign column: %s, foreign id: %s)',
                    $source->name, $rel_name, $foreign_cols[0], $foreign_id,
                    ;
                next;
            }

            $schema{ $self_schema }{ properties }{ $self_cols[0] }{ 'x-foreign-key' } = $foreign_schema;
        }
    }

    return @schema_names ? @schema{ @schema_names } : \%schema;
}

sub _map_type {
    my ( $self, $column ) = @_;
    my %conf;
    my $db_type = $column->{data_type} // 'varchar';

    if ( $column->{extra}{list} ) {
        %conf = ( enum => $column->{extra}{list} );
    }

    if ( $db_type =~ /^(?:text|varchar)/i ) {
        %conf = ( %conf, type => 'string' );
    }
    elsif ( $db_type =~ /^(?:boolean)/i ) {
        %conf = ( %conf, type => 'boolean' );
    }
    elsif ( $db_type =~ /^(?:int|integer|smallint|bigint|tinyint|rowid)/i ) {
        %conf = ( %conf, type => 'integer' );
    }
    elsif ( $db_type =~ /^(?:double|float|money|numeric|real)/i ) {
        %conf = ( %conf, type => 'number' );
    }
    elsif ( $db_type =~ /^(?:timestamp|datetime)/i ) {
        %conf = ( %conf, type => 'string', format => 'date-time' );
    }
    elsif ( $db_type =~ /(?:blob|bytea)/i ) {
        %conf = ( %conf, type => 'string', format => 'binary' );
    }
    else {
        # Default to string
        %conf = ( %conf, type => 'string' );
    }

    if ( $column->{is_nullable} ) {
        $conf{ type } = [ $conf{ type }, 'null' ];
    }

    #; use Data::Dumper;
    #; say "Field: " . Dumper $column;
    #; say "Conf: " . Dumper \%conf;

    return %conf;
}

sub supports { 0 }

1;
