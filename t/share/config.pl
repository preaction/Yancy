{
    plugins => [
        [ 'PODRenderer' ],
        [ 'Test' => { args => "one" } ],
    ],
    backend => 'test://localhost/',
    read_schema => 1,
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
