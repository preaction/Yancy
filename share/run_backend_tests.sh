
echo "-- Running Test (mock) tests"
prove t
if [ $? -gt 0 ]; then
    echo "Failed Test (mock) tests"
    exit 1
fi

echo "-- Running SQLite tests"
rm -f /tmp/yancy_sqlite3.db
sqlite3 /tmp/yancy_sqlite3.db < t/share/sqlite.sql
TEST_YANCY_BACKEND=sqlite:/tmp/yancy_sqlite3.db prove t
if [ $? -gt 0 ]; then
    echo "Failed SQLite tests"
    exit 1
fi

echo "-- Running MySQL tests"
mysql -e 'DROP DATABASE IF EXISTS test_yancy'
mysql -e 'CREATE DATABASE test_yancy'
mysql test_yancy < t/share/mysql.sql
TEST_YANCY_BACKEND=mysql:///test_yancy prove t
if [ $? -gt 0 ]; then
    echo "Failed MySQL tests"
    exit 1
fi

echo "-- Running Postgres tests"
dropdb test_yancy
createdb test_yancy
psql test_yancy < t/share/pg.sql
TEST_YANCY_BACKEND=pg:///test_yancy prove t
if [ $? -gt 0 ]; then
    echo "Failed Postgres tests"
    exit 1
fi

echo "-- Running DBIx::Class tests"
rm -f /tmp/yancy_dbic.db
sqlite3 /tmp/yancy_dbic.db < t/share/sqlite.sql
TEST_YANCY_BACKEND=dbic://Local::Schema/dbi:SQLite:/tmp/yancy_dbic.db prove t
if [ $? -gt 0 ]; then
    echo "Failed DBIx::Class tests"
    exit 1
fi

exit 0
