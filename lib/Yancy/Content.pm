package Yancy::Content;
use Mojo::Base 'Yancy::Model', -signatures;
use Scalar::Util qw( blessed );
use Mojo::JSON qw( true false );
use Mojo::Loader qw( data_section );
use Mojo::Util qw( decamelize );

=head1 DESCRIPTION

This is the content _model_: It provides and renders content, but does not contain
a content _editor_. That is provided elsewhere by L<Yancy::Plugin::Editor>.

=cut

sub new($class, @args) {
  my $self = $class->SUPER::new(@args);
  unshift @{$self->namespaces}, 'Yancy::Content';

  # Perform migrations for our backend
  # backend class minus Yancy::Backend::, lower-case.
  my ($ext) = blessed($self->backend) =~ s{Yancy::Backend::(\w+)}{\L$1}r;
  # try to find migrations.<key>
  if (my $migrations = data_section( __PACKAGE__, "migrations.$ext")) {
    # decamelize $class for migration name
    $self->backend->driver->migrations->name(decamelize(__PACKAGE__))->from_string($migrations)->migrate();
  }

  # Now that we have our database tables, we need to re-read the schema...
  $self->read_schema;

  return $self;
}

1;
__DATA__

@@ migrations.sqlite
-- 1 up
CREATE TABLE pages (
  page_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name STRING NOT NULL,
  method STRING NOT NULL,
  pattern STRING NOT NULL,
  title STRING,
  template STRING,
  params STRING NOT NULL DEFAULT '{}',
  in_app BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (name),
  UNIQUE (pattern)
);
CREATE TABLE blocks (
  block_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  path STRING NOT NULL,
  name STRING NOT NULL,
  content STRING,
  UNIQUE (path, name)
);
-- 1 down
DROP TABLE blocks;
DROP TABLE pages;
