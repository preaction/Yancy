package Local::Schema::Result::people;

use v5.24;
use experimental qw( signatures postderef );
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
);
__PACKAGE__->set_primary_key('id');

1;
