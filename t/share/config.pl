{
    plugins => [
        [ 'PODRenderer' ],
        [ 'Test' => { args => "one" } ],
    ],
    backend => 'test://localhost/',
    collections => {
        people => {
            required => [ 'name', 'email' ],
            properties => {
                name => {
                    type => 'string',
                },
                email => {
                    type => 'string',
                    pattern => '^[^@]+@[^@]+$',
                },
            },
        },
        users => {
            'x-id-field' => 'username',
            properties => {
                username => { type => 'string' },
                email => { type => 'string' },
                password => {
                    type => 'string',
                    format => 'password',
                },
            },
        },
    },
}
