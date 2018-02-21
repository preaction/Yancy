package Local::Schema::Result::blog;

use Mojo::Base '-strict';
use base 'DBIx::Class::Core';

__PACKAGE__->table('blog');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'integer',
    },
    qw/ title slug markdown html /,
);
__PACKAGE__->set_primary_key('id');

1;
