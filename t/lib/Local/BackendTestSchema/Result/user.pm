package Local::BackendTestSchema::Result::user;

use Mojo::Base '-strict';
use base 'DBIx::Class::Core';

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    qw/ username /,
    email => {
        is_nullable => 0,
    },
    access => {
        default_value => 'user',
        extra => {
            list => [qw( user moderator admin )],
        },
    },
    created => {
        data_type => 'datetime',
        is_nullable => 1,
        default_value => '2018-03-01 00:00:00',
    },
);
__PACKAGE__->set_primary_key('username');

1;
