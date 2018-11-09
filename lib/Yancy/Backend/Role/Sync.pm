package Yancy::Backend::Role::Sync;
our $VERSION = '1.014';
# ABSTRACT: A role to give a synchronous backend useful Promises methods

=head1 SYNOPSIS

    package Yancy::Backend::SyncOnly;
    with 'Yancy::Backend::Role::Sync';

    package main;
    my $be = Yancy::Backend::SyncOnly->new;
    my $promise = $be->create_p( \%item );

=head1 DESCRIPTION

This role implements C<list_p>, C<get_p>, C<set_p>, C<delete_p>, and
C<create_p> methods that return L<Mojo::Promise> objects for synchronous
backends. This does not make the backend asynchronous: The original,
synchronous method is called and a promise object created from the
result. The promise is then returned already fulfilled.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use Mojo::Promise;

sub _call_with_promise {
    my ( $self, $method, @args ) = @_;
    my @return = $self->$method( @args );
    my $promise = Mojo::Promise->new;
    $promise->resolve( @return );
}

sub list_p { return _call_with_promise( shift, list => @_ ) }
sub get_p { return _call_with_promise( shift, get => @_ ) }
sub set_p { return _call_with_promise( shift, set => @_ ) }
sub delete_p { return _call_with_promise( shift, delete => @_ ) }
sub create_p { return _call_with_promise( shift, create => @_ ) }

1;
