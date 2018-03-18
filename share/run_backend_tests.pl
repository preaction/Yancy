#!/usr/bin/env perl

=head1 NAME

run_backend_tests.pl - Run Yancy tests with a configured backend

=head1 SYNOPSIS

    # Run all tests for all backends
    ./share/run_backend_tests.pl

    # Run all tests for one or more backends
    ./share/run_backend_tests.pl <backend>...

    # Run one or more tests for all backends
    ./share/run_backend_tests.pl -- <test>...

    # Run one or more tests for one or more backends
    ./share/run_backend_tests.pl <backend>... -- <test>...

=head1 DESCRIPTION

This script helps to run Yancy tests under different backends to ensure
all backends have the same functionality.

=head2 BACKENDS

To run the Postgres tests, you must have a running Postgres server and the
current user must be authorized to access it without a password.

To run the MySQL tests, you must have a running MySQL server and the
current user must be authorized to access it without a password.

To run the SQLite and DBIx::Class tests, you simply must have a C</tmp>
folder.

=head1 ARGUMENTS

=head2 backend

A backend to test. One or more of: C<mock>, C<sqlite>, C<mysql>, C<pg>,
C<dbic>. Defaults to testing all backends, with the mock backend first.

=head2 test

A test file to run. Can be one or more paths to test directories or
files in the C<t> directory. The C<prove> program is run recursively
(with the C<-r> flag), so directories will be recursed. Defaults to
C<t>, which will run all the tests.

=head1 OPTIONS

No options at this time.

=head1 SEE ALSO

L<Yancy>

=cut

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
            'sqlite3 /tmp/yancy_sqlite3.db < t/schema/sqlite.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'sqlite:/tmp/yancy_sqlite3.db',
        },
    },

    mysql => {
        setup => [
            'mysql -e "DROP DATABASE IF EXISTS test_yancy"',
            'mysql -e "CREATE DATABASE test_yancy"',
            'mysql test_yancy < t/schema/mysql.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'mysql:///test_yancy',
        },
    },

    pg => {
        setup => [
            'dropdb test_yancy',
            'createdb test_yancy',
            'psql test_yancy < t/schema/pg.sql',
        ],
        env => {
            TEST_YANCY_BACKEND => 'pg:///test_yancy',
        },
    },

    dbic => {
        setup => [
            'rm -f /tmp/yancy_dbic.db',
            'sqlite3 /tmp/yancy_dbic.db < t/schema/sqlite.sql',
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

