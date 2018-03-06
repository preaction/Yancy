package Yancy::Controller::Yancy::MultiTenant;
our $VERSION = '0.023';
# ABSTRACT: A controller to show a user only their content

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        collections => {
            blog => {
                properties => {
                    id => { type => 'integer' },
                    user_id => { type => 'integer' },
                    title => { type => 'string' },
                    html => { type => 'string' },
                },
            },
        },
    };

    app->routes->get( '/user/:user_id' )->to(
        'yancy-multi_tenant#list',
        collection => 'blog',
        template => 'index'
    );

    __DATA__
    @@ index.html.ep
    % for my $item ( @{ stash 'items' } ) {
        <h1><%= $item->{title} %></h1>
        <%== $item->{html} %>
    % }

=head1 DESCRIPTION

This module contains routes to manage content owned by users. When paired
with an authentication plugin like L<Yancy::Plugin::Auth::Basic>, each user
is allowed to manage their own content.

=head1 SEE ALSO

L<Yancy::Controller::Yancy>, L<Mojolicious::Controller>

=cut

use Mojo::Base 'Mojolicious::Controller';


# XXX: Make this extend Yancy::Controller::Yancy


1;
