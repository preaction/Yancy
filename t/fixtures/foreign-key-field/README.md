
# Foreign Key Field Fixtures

## Address Types

This table tests basic operation of the foreign key field. The first
item in `x-list-columns` is a field name. The foreign key field uses
this field name to search and display results. The `x-id-field` is an
integer. This field is used as the value for the foreign key.

## Cities

This table tests that the foreign key field correctly searches multiple
fields. The first item in `x-list-columns` is set to an object
containing a template.  The foreign key field parses the template to
find which fields to search and uses the template to display the
results.


