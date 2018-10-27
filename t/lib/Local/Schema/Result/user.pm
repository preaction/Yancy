package Local::Schema::Result::user;

use Mojo::Base '-strict';
use base 'DBIx::Class::Core';

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    qw/ username /,
    email => {
        is_nullable => 0,
    },
    password => {
        is_nullable => 0,
    },
    access => {
        default_value => 'user',
        extra => {
            list => [qw( user moderator admin )],
        },
    },
    age => {
        data_type => 'integer',
        is_nullable => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([ 'username' ]);

1;
