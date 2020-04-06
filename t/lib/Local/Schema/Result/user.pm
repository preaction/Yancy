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
  "plugin",
  {
    data_type => "varchar",
    default_value => "password",
    is_nullable => 0,
    size => 50,
  },
  "avatar",
  {
    data_type     => "text",
    default_value => "",
    is_nullable   => 0,
    original      => { data_type => "varchar" },
  },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("user_username_key", ["username"]);
__PACKAGE__->has_many(
  "blog",
  "Local::Schema::Result::blog",
  { "foreign.username" => "self.username" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2020-04-05 20:04:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cA+6V363+bnUj4w+QW3+wQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
