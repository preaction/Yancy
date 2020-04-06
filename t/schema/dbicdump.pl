# To create db to dump from:
# ./xt/run_backend_tests.pl pg -- t/backend/pg.t
# To re-create DBIC:
# dbicdump t/schema/dbicdump.pl

{
    schema_class => 'Local::Schema',
    connect_info => {
        dsn => 'dbi:Pg:dbname=test_yancy'
    },
    loader_options => {
        overwrite_modifications => 1, # If we're running this, we want to rebuild it all
        dump_directory => 't/lib',
        generate_pod => 0,
        moniker_map => sub {
            my ( $table, $default_moniker, $othercode ) = @_;
            $table->name;
        },
        custom_column_info => sub {
            my ($table, $column_name, $column_info) = @_;
            return if !exists $column_info->{default_value};
            return if ref $column_info->{default_value} ne 'SCALAR';
            my %col_info;
            my $value = lc ${ $column_info->{default_value} };
            $col_info{default_value} =
                $value eq 'null' ? undef :
                $value eq 'false' ? 0 :
                $value eq 'true' ? 1 :
                \$value;
            \%col_info;
        },
        rel_name_map => sub {
            my ( $param ) = @_;
            return $param->{ remote_moniker };
        },
    },
}
