package Local::Schema::Result::wiki_pages {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'wiki_pages' );
    __PACKAGE__->add_columns(
        wiki_page_id => {
            data_type => 'integer',
            is_nullable => 0,
        },
        revision_date => {
            data_type => 'datetime',
            is_nullable => 0,
            default => \'CURRENT_TIMESTAMP',
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
            is_nullable => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'wiki_page_id', 'revision_date' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( wiki_pages );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn, undef, undef, {}, { quote_names => 1 } );
$schema->deploy({ sources => [qw( wiki_pages )] });

1;
