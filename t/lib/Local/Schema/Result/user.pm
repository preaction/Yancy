package Local::Schema::Result::user;

use v5.24;
use experimental qw( signatures postderef );
use base 'DBIx::Class::Core';

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    qw/ username /,
    email => {
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key('username');

1;
