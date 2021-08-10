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
    __PACKAGE__->has_many( addresses =>  'Local::Schema::Result::addresses', 'city_id' );
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
            is_nullable => 1,
            is_foreign_key => 1,
        },
        street => {
            data_type => 'text',
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'address_id' );
    __PACKAGE__->belongs_to( city_id =>  'Local::Schema::Result::cities', { 'foreign.city_id' => 'self.city_id' }, { join_type => 'left' } );
    __PACKAGE__->belongs_to( address_type_id =>  'Local::Schema::Result::address_types', 'address_type_id' );
}

package Local::Schema::Result::districts {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'districts' );
    __PACKAGE__->add_columns(
        district_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        district_code => {
            data_type => 'text',
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'district_id' );
}

package Local::Schema::Result::address_districts {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'address_districts' );
    __PACKAGE__->add_columns(
        address_id => {
            data_type => 'integer',
            is_nullable => 0,
            is_foreign_key => 1,
        },
        district_id => {
            data_type => 'integer',
            is_nullable => 0,
            is_foreign_key => 1,
        },
    );
    __PACKAGE__->set_primary_key( 'address_id', 'district_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( address_types cities addresses districts address_districts );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn );
$schema->deploy({ sources => [qw( address_types cities addresses districts address_districts )] });

1;
