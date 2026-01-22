# Yancy Example - Authentication Demo

This example demonstrates Password and Github authentication.

## Running the Example

You will need to install [Carton](https://metacpan.org/pod/Carton) from
CPAN. Then, from the `eg/auth-demo` directory:

    $ carton install
    $ carton exec ./myapp.pl eval 'app->yancy->model("users")->create({
        email => "admin\@example.com",
        password => "123qwe",
    })'
    $ carton exec ./myapp.pl daemon
    Server available at http://127.0.0.1:3000

Then visit <http://127.0.0.1:3000/yancy> to edit the site. Use
'admin@example.com' and '123qwe' to log in.

See [the Yancy Auth guide for more
information](http://preaction.me/yancy/perldoc/Yancy/Help/Auth/).
