package Local::Schema::Result::icons {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'icons' );
    __PACKAGE__->add_columns(
        icon_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        icon_name => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        icon_data => {
            data_type => 'blob',
            is_nullable => 1,
        },
    );
    __PACKAGE__->set_primary_key( 'icon_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( icons );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn, undef, undef, {}, { quote_names => 1 } );
$schema->deploy({ sources => [qw( icons )] });

1;
