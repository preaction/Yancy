package Local::Schema;

use v5.24;
use experimental qw( signatures postderef );
use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces();

1;
