package Local::Controller::Extend::Model;
use Mojo::Base 'Yancy::Controller::Model';

sub list {
    my ( $c ) = @_;
    $c->SUPER::list || return;
    $c->stash( items => [ $c->stash( 'items' )->[0] ] );
    $c->stash( 'extended' => 1 );
}

sub get {
    my ( $c ) = @_;
    $c->SUPER::get || return;
    $c->stash( 'item' => {
        %{ $c->stash( 'item' ) },
        title => 'Extended',
    } );
    $c->stash( 'extended' => 1 );
}

sub set {
    my ( $c ) = @_;
    $c->SUPER::set || return;
    $c->stash( 'extended' => 1 );
}

sub delete {
    my ( $c ) = @_;
    $c->SUPER::delete || return;
    $c->stash( 'extended' => 1 );
}

1;
