{
    plugins => [
        [ 'PODRenderer' ],
        [ 'Test' => { args => "one" } ],
    ],
    backend => 'test://localhost/',
    collections => {
        people => {
            properties => {
                email => {
                    pattern => '^[^@]+@[^@]+$',
                },
            },
        },
        users => {
            properties => {
                password => {
                    format => 'password',
                },
            },
        },
    },
}
