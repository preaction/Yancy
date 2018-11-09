
# Yancy Example - Documentation Website

This example shows the documentation for Yancy and some associated
informational and marketing pages.

## Running the Example

You will need to install [Carton](https://metacpan.org/pod/Carton) from
CPAN. Then, from the `eg/doc-site` directory:

    $ carton install
    $ carton exec ./myapp.pl daemon
    Server available at http://127.0.0.1:3000

Then visit <http://127.0.0.1:3000/yancy> to edit the site.

## Exporting the Site

To export this site as a static website, use [the `export`
command](http://metacpan.org/pod/Mojolicious::Command::Export):

    $ carton exec ./myapp.pl export

