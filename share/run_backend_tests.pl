#!/usr/bin/env perl

use Mojo::Base -strict;

my @default_tests = qw( mock sqlite mysql pg dbic );
@ARGV = @ARGV ? map lc, @ARGV : @default_tests;

my %tests = (
    mock => { setup => [ ], env => { } },

    sqlite => {
        setup => [
            'rm -f /tmp/yancy_sqlite3.db',
            'sqlite3 /tmp/yancy_sqlite3.db < t/share/sqlite.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'sqlite:/tmp/yancy_sqlite3.db',
        },
    },

    mysql => {
        setup => [
            'mysql -e "DROP DATABASE IF EXISTS test_yancy"',
            'mysql -e "CREATE DATABASE test_yancy"',
            'mysql test_yancy < t/share/mysql.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'mysql:///test_yancy',
        },
    },

    pg => {
        setup => [
            'dropdb test_yancy',
            'createdb test_yancy',
            'psql test_yancy < t/share/pg.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'pg:///test_yancy',
        },
    },

    dbic => {
        setup => [
            'rm -f /tmp/yancy_dbic.db',
            'sqlite3 /tmp/yancy_dbic.db < t/share/sqlite.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'dbic://Local::Schema/dbi:SQLite:/tmp/yancy_dbic.db',
        },
    },
);


DB: for my $db ( @ARGV ) {
    if ( !$tests{ $db } ) {
        say "No test for $db. Available tests: " . join ", ", keys %tests;
        next;
    }

    my $test = $tests{ $db };
    for my $cmd ( @{ $test->{setup} || [] } ) {
        system $cmd;
        if ( $? != 0 ) {
            say "Error setting up test: $?";
            next DB;
        }
    }

    local %ENV = ( %ENV, %{ $test->{env} } );
    system qw( prove -lr t );
    if ( $? != 0 ) {
        say "Test failure: $?";
        last;
    }

    for my $cmd ( @{ $test->{teardown} || [] } ) {
        system $cmd;
        if ( $? != 0 ) {
            say "Error tearing down test: $?";
        }
    }
}

