# This script updates all the files for bundled projects. Edit the URL
# and then re-run the script to upgrade the projects.
#
# Run the script from the project root: ./share/update_resources.sh

mkdir -p lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/{css,fonts}

curl https://cdnjs.cloudflare.com/ajax/libs/jquery/3.2.1/jquery.min.js \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/jquery.js
curl https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-beta/css/bootstrap.min.css \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/bootstrap.css
curl https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-beta/js/bootstrap.min.js \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/bootstrap.js
curl https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.8/umd/popper.min.js \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/popper.js
curl https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/css/font-awesome.css
curl 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.eot' \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/fonts/fontawesome-webfont.eot
curl 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.woff2' \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/fonts/fontawesome-webfont.woff2
curl 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.woff' \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/fonts/fontawesome-webfont.woff
curl 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.ttf' \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/fonts/fontawesome-webfont.ttf
curl 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.svg' \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/font-awesome/fonts/fontawesome-webfont.svg
curl https://cdnjs.cloudflare.com/ajax/libs/vue/2.5.3/vue.min.js \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/vue.js
curl https://cdnjs.cloudflare.com/ajax/libs/marked/0.3.7/marked.min.js \
    > lib/Mojolicious/Plugin/Yancy/resources/public/yancy/marked.js

