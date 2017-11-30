package Local::Schema::Result::User;

use v5.24;
use experimental qw( signatures postderef );
use base 'DBIx::Class::Core';

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    qw/ username email /,
);
__PACKAGE__->set_primary_key('username');

1;
