
root=$(dirname $0)
deploy=$root/deploy

if [ ! -d $deploy ]; then
    mkdir $deploy
fi
perl $root/myapp.pl export -m preaction --to $deploy
rsync -rvzm --delete $deploy/. preaction.me:/var/www/www.preaction.me/yancy/.
