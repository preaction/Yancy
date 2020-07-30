package Yancy::Command::backend;
our $VERSION = '1.066';
# ABSTRACT: Commands for working with Yancy backends

=head1 SYNOPSIS

    Usage: APPLICATION backend COMMAND

        ./myapp.pl backend copy sqlite:prod.db users

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Commands';

has description => 'Work with Yancy backend';
has usage => sub { shift->extract_usage };
has hint => sub { "\nSee 'APPLICATION backend help COMMAND' for more information on a specific command.\n" };
has message => sub { shift->usage . "\nCommands:\n" };

# Mojolicious::Commands delegates to a module in this namespace
has namespaces => sub { [ 'Yancy::Command::backend' ] };

sub help { shift->run( @_ ) }

1;
