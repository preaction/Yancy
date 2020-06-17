package Local::CamelSchema::Result::Cities {
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
