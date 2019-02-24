use utf8;
package Local::Schema::Result::user;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table("user");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "user_id_seq",
  },
  "username",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "email",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "password",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "access",
  {
    data_type => "enum",
    default_value => "user",
    extra => {
      custom_type_name => "access_level",
      list => ["user", "moderator", "admin"],
    },
    is_nullable => 0,
  },
  "age",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("user_username_key", ["username"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-02-24 05:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rlivS0ctT5LTQhas7AaPwg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
