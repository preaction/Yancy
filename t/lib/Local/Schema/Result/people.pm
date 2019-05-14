use utf8;
package Local::Schema::Result::people;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table("people");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "people_id_seq",
  },
  "name",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "email",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "age",
  { data_type => "integer", is_nullable => 1 },
  "contact",
  { data_type => "boolean", default_value => 0, is_nullable => 1 },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-02-24 05:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aKG4eghPsxAlXficFCiBeA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
