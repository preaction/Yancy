
=head1 DESCRIPTION

This tests the configuration phase of Yancy, and any errors that could
occur (like missing ID fields).

=cut

use Mojo::Base -strict;
use Test::More;
use Yancy;

subtest 'errors' => sub {

    subtest 'missing id field' => sub {
        my %missing_id = (
            collections => {
                foo => {
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
        );
        eval { Yancy->new( config => \%missing_id ) };
        ok $@, 'configuration dies';
        like $@, qr{ID field missing in properties for collection 'foo', field 'id'},
            'error is correct';

        my %missing_x_id = (
            collections => {
                foo => {
                    'x-id-field' => 'bar',
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
        );
        eval { Yancy->new( config => \%missing_x_id ) };
        ok $@, 'configuration dies';
        like $@, qr{ID field missing in properties for collection 'foo', field 'bar'},
            'error is correct';

        my %ignored_missing_id = (
            collections => {
                foo => {
                    'x-ignore' => 1,
                    properties => {
                        text => { type => 'string' },
                    },
                },
            },
        );
        eval { Yancy->new( config => \%ignored_missing_id ) };
        ok !$@, 'configuration succeeds' or diag $@;
    };
};

done_testing;
