package Yancy::I18N;
our $VERSION = '1.080';
# ABSTRACT: Internationalization (i18n) for Yancy

=head1 SYNOPSIS

    # XXX: Show how to set the language of Yancy
    # XXX: Show how to create a custom lexicon
    # XXX: Show examples of bracket notation (quant, numf, numerate,
    # sprintf, and positional parameters)

=head1 DESCRIPTION

This is the internationalization module for Yancy. It uses L<Locale::Maketext> to do
the real work.

B<NOTE:> This is a work-in-progress and not all of Yancy's text has been made available
for translation. Patches welcome!

=head2 Languages

Yancy comes with the following lexicons:

=over

=item L<English (US)|Yancy::I18N::en>

=back

=head2 Custom Lexicons

To create your own lexicon, start from an existing Yancy lexicon and add your own
entries, like so:

    package MyApp::I18N;
    use Mojo::Base 'Yancy::I18N';

    package MyApp::I18N::en;
    use Mojo::Base 'Yancy::I18N::en';
    our %Lexicon = (
        'Additional entry' => 'Additional entry',
    );

=head1 SEE ALSO

L<Mojolicious::Plugin::I18N>, L<Locale::Maketext>

=cut

use Mojo::Base '-strict';
use base 'Locale::Maketext';

1;
