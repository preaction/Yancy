
# Northwind Traders

This is a Yancy example for the Northwind Traders example database that shipped
with Microsoft Access.

This example requires Perl 5.28 or later.

## SQLite

To load the database:

    rm -f northwind.sqlite
    sqlite3 northwind.sqlite < northwind-schema.sqlite.sql
    sqlite3 northwind.sqlite < northwind-data.sql

To run the application:

    carton exec morbo myapp.pl

This application uses the `myapp.conf` file for configuration.

## MySQL

To load the database:

    mysql northwind < northwind-schema.mysql.sql
    mysql northwind < northwind-data.sql

To run the application:

    carton exec morbo myapp.pl -m mysql

This application uses the `myapp.mysql.conf` file for configuration.

## Postgres

To load the database:

    dropdb --if-exists northwind
    createdb northwind
    psql northwind < northwind-schema.pg.sql
    psql northwind < northwind-data.sql

To run the application:

    carton exec morbo myapp.pl -m pg

This application uses the `myapp.pg.conf` file for configuration.

