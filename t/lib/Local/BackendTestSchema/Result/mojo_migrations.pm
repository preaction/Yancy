package Local::BackendTestSchema::Result::mojo_migrations;

use Mojo::Base '-strict';
use base 'DBIx::Class::Core';

__PACKAGE__->table('mojo_migrations');
__PACKAGE__->add_columns(
    name => {
        data_type => 'varchar',
        is_nullable => 0,
    },
    version => {
        data_type => 'integer',
        is_nullable => 0,
    },
);
__PACKAGE__->add_unique_constraint(['name']);

1;
