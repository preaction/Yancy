package Local::Schema::Result::people;

use Mojo::Base '-strict';
use base 'DBIx::Class::Core';

__PACKAGE__->table('people');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    qw/ name /,
    email => {
        is_nullable => 1,
    },
    age => {
        data_type => 'integer',
        is_nullable => 1,
    },
    contact => {
        data_type => 'boolean',
        is_nullable => 1,
    },
    phone => {
        data_type => 'string',
        is_nullable => 1,
        size => 50,
    },
);
__PACKAGE__->set_primary_key('id');

1;
