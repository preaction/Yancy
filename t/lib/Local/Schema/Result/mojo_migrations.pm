use utf8;
package Local::Schema::Result::mojo_migrations;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table("mojo_migrations");
__PACKAGE__->add_columns(
  "name",
  { data_type => "text", is_nullable => 0 },
  "version",
  { data_type => "bigint", is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint("mojo_migrations_name_key", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-02-24 05:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jSRmX4wQVBKSroqrgW4rfA

sub yancy {
    +{ 'x-ignore' => 1 };
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
