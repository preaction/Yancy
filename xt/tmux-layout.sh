session=yancy
if ! tmux has-session -t $session; then
    tmux new-session -s $session -d
    tmux rename-window -t $session:1 code
    tmux new-window -t $session:2 -n test
    tmux send-keys -t $session:1 vim Enter
    tmux send-keys -t $session:2.0 "export TEST_YANCY_EXAMPLES=1" Enter
    tmux send-keys -t $session:2.0 "export TEST_ONLINE_MYSQL=mysql://localhost/yancy_mysql_test" Enter
    tmux send-keys -t $session:2.0 "export TEST_ONLINE_PG=postgres://localhost/test" Enter
    tmux send-keys -t $session:2.0 "export TEST_SELENIUM=1" Enter
    # This doesn't work yet...
    # tmux send-keys -t $session:2.0 "export MOJO_SELENIUM_DRIVER='Selenium::Remote::Driver&browser_name=chrome'" Enter
    # tmux split-window -t $session:2 docker run --rm -p 4444:4444 --shm-size=2g selenium/standalone-chrome:3.141.59
    tmux new-window -t $session:3 -n db postgres -D ~/perl/Yancy/db/pg
    tmux split-window -t $session:3 mysqld --skip-grant-tables --datadir ~/perl/Yancy/db/mysql
    tmux select-window -t $session:1
fi
tmux attach -t $session
