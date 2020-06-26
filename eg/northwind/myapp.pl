#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::JSON qw( true false );

plugin AutoReload => {};
plugin Config => { default => {} };
plugin Moai => [ 'Bootstrap4', { version => '4.4.1' } ];

plugin 'Yancy', {
    backend => app->config->{yancy}{backend},
    read_schema => 1,
    editor => { require_user => undef, },
    schema => app->config->{yancy}{schema},
};








# Enable modern perl features by default in templates
plugin EPRenderer => {
    template => {
        prepend => q{
            use v5.28;
            use experimental qw( signatures postderef );
        },
    },
};

get '/' => {
    controller  => 'yancy',
    action      => 'list',
    schema      => 'products',
    template    => 'product_list',
}, 'product.list';

get '/product/:product_id' => {
    controller  => 'yancy',
    action      => 'get',
    schema      => 'products',
    template    => 'product_details',
}, 'product.details';

app->start;
