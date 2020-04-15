package Local::Schema::Result::rolodex {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'rolodex' );
    __PACKAGE__->add_columns(
        rolodex_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        name => {
            data_type => 'text',
            is_nullable => 0,
        },
        phone => {
            data_type => 'text',
            is_nullable => 1,
        },
        email => {
            data_type => 'text',
            is_nullable => 1,
        },
    );
    __PACKAGE__->set_primary_key( 'rolodex_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( rolodex );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn );
$schema->deploy({ sources => [qw( rolodex )] });

1;
