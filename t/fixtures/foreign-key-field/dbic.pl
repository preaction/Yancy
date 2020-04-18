package Local::Schema::Result::address_types {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'address_types' );
    __PACKAGE__->add_columns(
        address_type_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        address_type => {
            data_type => 'text',
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'address_type_id' );
}

package Local::Schema::Result::cities {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'cities' );
    __PACKAGE__->add_columns(
        city_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        city_name => {
            data_type => 'text',
            is_nullable => 0,
        },
        city_state => {
            data_type => 'text',
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'city_id' );
}

package Local::Schema::Result::addresses {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'addresses' );
    __PACKAGE__->add_columns(
        address_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        address_type_id => {
            data_type => 'integer',
            is_nullable => 0,
            is_foreign_key => 1,
        },
        city_id => {
            data_type => 'integer',
            is_nullable => 0,
            is_foreign_key => 1,
        },
        street => {
            data_type => 'text',
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'address_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( address_types cities addresses );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn );
$schema->deploy({ sources => [qw( address_types cities addresses )] });

1;
