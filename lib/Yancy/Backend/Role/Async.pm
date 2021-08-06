package Yancy::Backend::Role::Async;
our $VERSION = '1.075';
# ABSTRACT: A role to give an asynchronous backend useful synchronous
# methods

=head1 SYNOPSIS

    package Yancy::Backend::AsyncOnly;
    with 'Yancy::Backend::Role::Async';

    package main;
    my $be = Yancy::Backend::AsyncOnly->new;
    my $row = $be->create( \%item );

=head1 DESCRIPTION

This role implements C<list>, C<get>, C<set>, C<delete>, and C<create>
methods based on the corresponding asynchronous methods that return
L<Mojo::Promise> objects.

=head1 SEE ALSO

L<Yancy::Backend>

=cut

use Mojo::Base '-role';
use Mojo::IOLoop;

sub _call_blocking {
    my ( $self, $method, @args ) = @_;
    my $promise = $self->$method( @args );
    my @return;
    $promise->then(sub { @return = @_ });
    $promise->ioloop->reactor->one_tick until @return;
    return wantarray ? @return : $return[-1];
}

sub list { return _call_blocking( shift, list_p => @_ ) }
sub get { return _call_blocking( shift, get_p => @_ ) }
sub set { return _call_blocking( shift, set_p => @_ ) }
sub delete { return _call_blocking( shift, delete_p => @_ ) }
sub create { return _call_blocking( shift, create_p => @_ ) }

1;
