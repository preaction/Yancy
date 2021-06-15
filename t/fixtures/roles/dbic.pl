package Local::Schema::Result::roles {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'roles' );
    __PACKAGE__->add_columns(
        username => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        role => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'username', 'role' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( roles );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn, undef, undef, {}, { quote_names => 1 } );
$schema->deploy({ sources => [qw( roles )] });

1;
