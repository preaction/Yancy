package Yancy::Plugin::Auth;
our $VERSION = '1.019';
# ABSTRACT: Add one or more authentication plugins to your site

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        collections => {
            users => {
                properties => {
                    id => { type => 'integer', readOnly => 1 },
                    plugin => {
                        type => 'string',
                        enum => [qw( password token )],
                    },
                    username => { type => 'string' },
                    # Optional password for Password auth
                    password => { type => 'string' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth' => {
        collection => 'users',
        username_field => 'username',
        password_field => 'password',
        plugin_field => 'plugin',
        plugins => [
            {
                name => 'Password',
                password_digest => {
                    type => 'SHA-1',
                },
            },
            'Token',
            'Github',
        ],
    } );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin adds authentication to your site.

Multiple authentication plugins can be added with this plugin. If you
only ever want to have one type of auth, you can use that auth plugin
directly if you want.

=head1 CONFIGURATION

=head2 collection

=head2 username_field

=head2 password_field

=head2 plugin_field

=head2 plugins

=head2 Sessions

This module uses L<Mojolicious
sessions|https://mojolicious.org/perldoc/Mojolicious/Controller#session>
to store the login information in a secure, signed cookie.

To configure the default expiration of a session, use
L<Mojolicious::Sessions
default_expiration|https://mojolicious.org/perldoc/Mojolicious/Sessions#default_expiration>.

    use Mojolicious::Lite;
    # Expire a session after 1 day of inactivity
    app->sessions->default_expiration( 24 * 60 * 60 );

=head1 TEMPLATES

=head2 yancy/auth/login.html.ep

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Loader qw( load_class );
use Yancy::Util qw( currym );

has _plugins => sub { [] };

sub register {
    my ( $self, $app, $config ) = @_;

    for my $plugin_conf ( @{ $config->{plugins} } ) {
        my $name;
        if ( !ref $plugin_conf ) {
            $name = $plugin_conf;
            $plugin_conf = {};
        }
        else {
            ( $name, $plugin_conf ) = %$plugin_conf;
        }

        my $class = join '::', 'Yancy::Plugin::Auth', $name;
        if ( my $e = load_class( $class ) ) {
            die sprintf 'Unable to load auth plugin %s: %s', $name, $e;
        }
        if ( $config->{route} ) {
            $plugin_conf->{route} //= $config->{route}->any( lc $name );
        }
        my $plugin = $class->new( { %$config, %$plugin_conf } );
        push @{ $self->_plugins }, $plugin;
        # Plugin hashref overrides config from main Auth plugin
        $plugin->init( $app, { %$config, %$plugin_conf } );
    }

    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.plugins' => currym( $self, 'plugins' ),
    );
}

sub current_user {
    my ( $self, $c ) = @_;
    for my $plugin ( @{ $self->_plugins } ) {
        if ( my $user = $plugin->current_user( $c ) ) {
            return $user;
        }
    }
    return undef;
}

sub plugins {
    my ( $self, $c ) = @_;
    return @{ $self->_plugins };
}

1;
