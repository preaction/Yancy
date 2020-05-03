
# Yancy Example - Limited Editor

This example has a second instance of the Yancy editor with limited
capabilities: The "editor" user is only allowed to edit the `blog_posts`
schema, and only the `title`, `content`, and `content_html` fields. This
prevents them from editing users or changing the (slug) URL or date of
the blog posts. Additionally, a filter is installed to generate the
(slug) URL from the title of the post (if necessary).

# Run the Example

You will need to install [Carton](https://metacpan.org/pod/Carton) from
CPAN. Then, from the `eg/limited-editor` directory:

    $ carton install
    $ carton exec ./myapp.pl daemon
    Server available at http://127.0.0.1:3000

These users exist in the application:

1. Username: *admin*, Password: *admin* - The administrator, who can
   view the primary Yancy editor at <http://127.0.0.1:3000/yancy>.
2. Username: *editor*, Password: *editor* - The editor, who can use the
   limited editor at <http://127.0.0.1:3000/edit>.
3. Username: *user*, Password: *user* - A regular user, who is not
   allowed to see either editor.

