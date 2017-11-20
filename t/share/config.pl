{
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
    },
}
