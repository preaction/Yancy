
root=$(dirname $0)
scp $root/cpanfile preaction.me:app/todo-app
scp $root/myapp.pl preaction.me:app/todo-app
scp $root/todo-app.service preaction.me:.config/systemd/user
ssh preaction.me 'cd app/todo-app && carton install'
ssh preaction.me 'systemctl --user daemon-reload'
ssh preaction.me 'systemctl --user enable todo-app.service'
ssh preaction.me 'systemctl --user restart todo-app.service'
