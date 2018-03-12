#!/usr/bin/env perl

use Mojo::Base -strict;

my @default_tests = qw( mock sqlite mysql pg dbic );

my ( @tests, @files );
my $found_dashes = 0;
for my $item ( @ARGV ) {
    if ( $item eq '--' ) {
        $found_dashes = 1;
        next;
    }
    if ( $found_dashes ) {
        ; say "Adding item $item";
        push @files, $item;
    }
    else {
        ; say "Adding test $item";
        push @tests, $item;
    }
}

if ( !@tests ) {
    @tests = @default_tests;
}
if ( !@files ) {
    @files = ( 't' );
}

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


DB: for my $db ( @tests ) {
    if ( !$tests{ $db } ) {
        say "No test for $db. Available tests: " . join ", ", keys %tests;
        next;
    }

    say "-- Running test: $db";
    my $test = $tests{ $db };
    for my $cmd ( @{ $test->{setup} || [] } ) {
        system $cmd;
        if ( $? != 0 ) {
            say "Error setting up test: $?";
            next DB;
        }
    }

    local %ENV = ( %ENV, %{ $test->{env} } );
    system( qw( prove -lr ), @files );
    if ( $? != 0 ) {
        say "Test failure ($db): $?";
        last;
    }

    for my $cmd ( @{ $test->{teardown} || [] } ) {
        system $cmd;
        if ( $? != 0 ) {
            say "Error tearing down test: $?";
        }
    }

    say "-- Passed test: $db";
}

