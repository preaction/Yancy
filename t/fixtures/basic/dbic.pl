package Local::Schema::Result::employees {
    use base 'DBIx::Class::Core';
    __PACKAGE__->table( 'employees' );
    __PACKAGE__->add_columns(
        employee_id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        name => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        ssn => {
            data_type => 'varchar',
            size => 11,
            is_nullable => 0,
        },
        department => {
            data_type => 'enum',
            default_value => 'unknown',
            is_nullable => 0,
            extra => {
                list => [qw( unknown admin support development sales )],
            },
        },
        salary => {
            data_type => 'integer',
            is_nullable => 0,
            default_value => 0,
        },
        email => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 0,
        },
        desk_phone => {
            data_type => 'varchar',
            size => 12,
            is_nullable => 1,
            default_value => undef,
        },
        bio => {
            data_type => 'text',
            is_nullable => 1,
            default_value => undef,
        },
        '401k_percent' => {
            accessor => 'percent_401k',
            data_type => 'double',
            default_value => 0,
        },
    );
    __PACKAGE__->set_primary_key( 'employee_id' );
}

use Local::Schema;
Local::Schema->register_class(
    $_ => 'Local::Schema::Result::' . $_
) for qw( employees );
my ( $backend, $class, $dsn )
    = $ENV{TEST_YANCY_BACKEND} =~ m{^([^:]+):(?://([^/]*)/)?(.+)};
my $schema = $class->connect( $dsn );
$schema->deploy({ sources => [qw( employees )] });

1;
