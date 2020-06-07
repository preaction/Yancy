package Local::Schema::Result::pages {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'pages' );
    __PACKAGE__->add_columns(
        page_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        title => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        slug => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        content => {
            data_type => 'text',
        },
        content_html => {
            data_type => 'text',
        },
    );
    __PACKAGE__->set_primary_key( 'page_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( pages );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn, undef, undef, {}, { quote_names => 1 } );
$schema->deploy({ sources => [qw( pages )] });

1;
