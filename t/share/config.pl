{
    plugins => [
        [ 'Test' => { args => "one" } ],
    ],
    backend => 'test://localhost/',
    read_schema => 1,
    collections => {
        people => {
            properties => {
                name => {
                    description => 'The real name of the person',
                },
                email => {
                    pattern => '^[^@]+@[^@]+$',
                },
            },
        },
        users => {
            'x-list-columns' => [qw( username email )],
            properties => {
                password => {
                    format => 'password',
                },
            },
        },
    },
}
