
=head1 DESCRIPTION

This tests the Yancy::Model class and its inner classes (Yancy::Model::Schema and
Yancy::Model::Item).

=cut

use Mojo::Base -strict;
use Test::More;
use Yancy::Model;
use FindBin qw( $Bin );
use Mojo::File qw( path );
use lib "".path( $Bin, 'lib' );
use Local::Test qw( init_backend );

my ( $backend_url, $backend, %items ) = init_backend( \%Yancy::Backend::Test::SCHEMA );

my $model = Yancy::Model->new( backend => $backend )->read_schema;
my ( $fry_id, $leela_id, $bender_id );

subtest 'Schema->create' => sub {
    $fry_id = $model->schema( 'user' )->create({
        username => 'fry',
        email => 'fry@planex.com',
        password => '12345',
    });
    is $fry_id, 'fry', 'id is returned';
    $leela_id = $model->schema( 'user' )->create({
        username => 'leela',
        email => 'leela@planex.com',
        password => '1bdi',
    });
    is $leela_id, 'leela', 'id is returned';
    $bender_id = $model->schema( 'user' )->create({
        username => 'bender',
        email => 'bender@mom.corp',
        password => 'iamnotgivingmypasswordtoamachine',
    });
    is $bender_id, 'bender', 'id is returned';
};

subtest 'Schema->get' => sub {
    my $fry = $model->schema( 'user' )->get( $fry_id );
    isa_ok $fry, 'Yancy::Model::Item';
    is $fry->data->{username}, 'fry', 'username is correct';
};

subtest 'Schema->list' => sub {
    my $res = $model->schema( 'user' )->list;
    is scalar @{ $res->{items} }, 3, '3 items returned';
    is $res->{total}, 3, '3 items total';
    isa_ok $res->{items}[0], 'Yancy::Model::Item';
    isa_ok $res->{items}[1], 'Yancy::Model::Item';
    isa_ok $res->{items}[2], 'Yancy::Model::Item';

    $res = $model->schema( 'user' )->list({ email => { -like => '%@planex.com' } });
    is scalar @{ $res->{items} }, 2, '2 items returned';
    is $res->{total}, 2, '2 items total';
    isa_ok $res->{items}[0], 'Yancy::Model::Item';
    isa_ok $res->{items}[1], 'Yancy::Model::Item';
};

subtest 'Item->set' => sub {
    my $bender = $model->schema( 'user' )->get( $bender_id );
    my $ok = $bender->set({ password => 'secret' });
    ok $ok, 'set is successful';
    is $bender->data->{password}, 'secret', 'password is updated in object';
    is $model->schema( 'user' )->get( $bender_id )->data->{password}, 'secret',
        'password is updated in database';
};

subtest 'Schema->delete' => sub {
    my $flexo_id = $model->schema( 'user' )->create({
        username => 'flexo',
        email => 'flexo@planex.com',
        password => 'flexooutranksmesir',
    });
    is $flexo_id, 'flexo', 'id is returned';
    ok $model->schema( 'user' )->get( $flexo_id ), 'flexo is in the database';
    ok $model->schema( 'user' )->delete( $flexo_id ), 'flexo is deleted';
    ok !$model->schema( 'user' )->get( $flexo_id ), 'flexo is not in the database';
};

subtest 'Item->delete' => sub {
    my $flexo_id = $model->schema( 'user' )->create({
        username => 'flexo',
        email => 'flexo@planex.com',
        password => 'flexooutranksmesir',
    });
    is $flexo_id, 'flexo', 'id is returned';
    my $flexo = $model->schema( 'user' )->get( $flexo_id );
    $flexo->delete;
    ok !$model->schema( 'user' )->get( $flexo_id ), 'flexo is not in the database';
};

subtest 'Item properties' => sub {
    my $fry = $model->schema( 'user' )->get( $fry_id );
    is $fry->{username}, 'fry', 'deref gets row data';
};

done_testing;

