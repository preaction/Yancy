package Digest::BcryptYancy;

use strictures 2;
use utf8;

use Mu;
use MooX::Clone;

use Carp 'croak';
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 de_base64 );
use Data::Entropy::Algorithms 'rand_bits';

require bytes;

extends "Digest::base";

our $VERSION = '0.1';

rw _buffer => default => sub { '' };

rw cost => isa => sub {
    return if defined $_[0] and $_[0] =~ /^[0-9]+$/;
    croak "Cost must be a positive integer";
} => clearer => 1 => coerce => sub { sprintf "%02d", $_[0] };

rw salt => isa => sub {
    return if $_[0] && $_[0] =~ /[.\/A-Za-z0-9]{22}/;
    croak "Salt must be exactly 22 base 64 digits";
} => clearer => 1 => default => sub { en_base64 rand_bits 16 * 8 };

around new => sub {
    my ( $orig, $class, %args ) = @_;
    return $class->$orig(%args) unless    #
      my $settings = delete $args{settings};
    $settings = de_base64 $settings;
    croak "bad bcrypt settings:\n$settings"
      unless $settings =~ m#\A\$2a\$([0-9]{2})\$([./A-Za-z0-9]{22})#;
    $args{cost} = $1;
    $args{salt} = $2;
    return $class->$orig(%args);
};

sub add {
    my ( $self, @data ) = @_;
    $self->_buffer( join '', $self->_buffer, @data );
    return $self;
}

sub b64digest { shift->digest }

sub digest {
    my ($self)   = @_;
    my $settings = join '$', "", "2a", $self->cost, $self->salt;
    my $hash     = en_base64 bcrypt $self->_buffer, $settings;
    $self->reset;
    return $hash;
}

sub reset {
    my ($self) = @_;
    $self->_buffer('');
    $self->$_ for map "clear_$_", qw( cost salt );
    return $self;
}

1;
