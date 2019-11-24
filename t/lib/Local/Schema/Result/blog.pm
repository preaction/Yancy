use utf8;
package Local::Schema::Result::blog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table("blog");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "blog_id_seq",
  },
  "username",
  { data_type => "text", is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "slug",
  { data_type => "text", is_nullable => 1 },
  "markdown",
  { data_type => "text", is_nullable => 0 },
  "html",
  { data_type => "text", is_nullable => 1 },
  "is_published",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
    user => 'Local::Schema::Result::user',
    { 'foreign.username' => 'self.username' },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-02-24 05:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vh3OOEKAvmqevDlNZiUDvg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
