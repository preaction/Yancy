package Yancy::Content;
use Mojo::Base 'Yancy::Model', -signatures;
use Mojo::JSON qw( true false );

=head1 DESCRIPTION

This is the content _model_: It provides and renders content, but does not contain
a content _editor_. That is provided elsewhere by L<Yancy::Plugin::Editor>.

=cut

has namespaces => sub { [qw( Yancy::Content Yancy::Model )] };

1;
