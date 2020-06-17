package Local::CamelSchema::Result::Addresses {
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
    __PACKAGE__->belongs_to( city => 'Local::CamelSchema::Result::Cities' => 'city_id' );
}
