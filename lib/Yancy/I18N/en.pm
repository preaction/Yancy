package Yancy::I18N::en;
our $VERSION = '1.063';
# ABSTRACT: English lexicon for Yancy strings

=head1 DESCRIPTION

This is the (default) English lexicon for Yancy. Since English is the default, this is
largely intended to be a starting point for your own translation, listing all the
necessary lexicon entries and describing them.

=head1 SEE ALSO

L<Yancy::I18N>, L<Mojolicious::Plugin::I18N>, L<Locale::Maketext>

=cut

use Mojo::Base '-strict';
use base 'Yancy::I18N';
our %Lexicon = (
    _AUTO => 1,

    # Label for returning to the site from the Yancy editor
    'Back to Application' => 'Back to Application',

    # Short label for returning to the site from the Yancy editor (on
    # small screens)
    'Back' => 'Back',

    # Display label for button to show/hide navigation panel on small
    # screens
    'Menu' => 'Menu',

    # ARIA Label for button to show/hide navigation panel on small screens
    'Toggle navigation' => 'Toggle navigation',

    # Label for the list of schemas/tables configured on the site
    'Schema' => 'Schema',

    # Label for button to reload the current page of items from the
    # server
    'Refresh' => 'Refresh',

    # Label for button to visit the x-view-url for a schema
    'View' => 'View',

    # Label for button to visit the x-view-url for an item
    'View Item' => 'View',

    # Label for button to add a new search filter
    'Add Filter' => 'Add Filter',

    # Label for button to save and activate a new search filter
    'Add' => 'Add',

    # Label for button to remove a search filter
    'Remove' => 'Remove',

    # Label for button to add a new item/row to a schema
    'Add Item' => 'Add Item',

    # Label for an error message from server
    'Error from server:' => 'Error from server:',

    # Error title used when Yancy could not find any schemas to manage
    'No Schema Configured' => 'No Schema Configured',

    # Error description used when Yancy could not find any schemas to
    # manage (HTML allowed)
    'No Schema Configured description' => 'Please configure your data schema, or have Yancy scan your database by setting <code>read_schema =&gt; 1</code>.',

    # Error title used when Yancy could not fetch the API specification
    'Error Fetching API Spec' => 'Error Fetching API Spec',

    # Error description used when Yancy could not fetch the API
    # specification
    'Error Fetching API Spec description' => 'Please check the logs, fix the error, and reload the page.',

    # Error title used when Yancy fails to get requested data
    'Error Fetching Data' => 'Error Fetching Data',

    # Error title used when Yancy fails to add an item
    'Error Adding Item' => 'Error Adding Item',

    # OpenAPI description of the '$match' parameter for list actions
    'OpenAPI $match description' => 'How to combine the filtering of multiple columns. Use "any" to see items that match at least one of the filters. Use "all" to see items that match all filters.',

    # OpenAPI description of the '$order_by' parameter for list actions
    'OpenAPI $order_by description' => 'How to sort the list. A string containing one of "asc" (to sort in ascending order) or "desc" (to sort in descending order), followed by a ":", followed by the field name to sort by.',

    # OpenAPI description of the '$offset' parameter for list actions
    'OpenAPI $offset description' => 'The index (0-based) to start returning items.',

    # OpenAPI description of the '$limit' parameter for list actions
    'OpenAPI $limit description' => 'The number of items to return.',

    # OpenAPI description for a filter query parameter
    # Gets one parameter: The name of the field.
    'OpenAPI filter description' => 'Filter the list by the [_1] field.',

    # Additional text in the OpenAPI description for a filter query parameter (number/integer)
    'OpenAPI filter number description' => 'Looks for records where the number is equal to the value.',

    # Additional text in the OpenAPI description for a filter query parameter (boolean)
    'OpenAPI filter boolean description' => 'Looks for records where the boolean is true/false.',

    # Additional text in the OpenAPI description for a filter query parameter (string)
    'OpenAPI filter string description' => 'By default, looks for records containing the value anywhere in the column. Use "*" anywhere in the value to anchor the match.',

    # Additional text in the OpenAPI description for a filter query parameter (array)
    'OpenAPI filter array description' => 'Looks for records where the array contains the value.',
);

1;
