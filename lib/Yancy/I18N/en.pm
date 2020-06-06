package Yancy::I18N::en;
our $VERSION = '1.059';
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
);

1;
