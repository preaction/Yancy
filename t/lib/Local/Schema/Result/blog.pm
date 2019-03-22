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
        is_nullable => 1,
    },
    title => { is_nullable => 0 },
    slug => { is_nullable => 1 },
    markdown => { is_nullable => 0 },
    html => { is_nullable => 1 },
    is_published => {
        data_type => 'boolean',
        default_value => 0,
    },
);
__PACKAGE__->set_primary_key('id');

1;
