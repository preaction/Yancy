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
        users => {
            'x-id-field' => 'username',
            properties => {
                username => { type => 'string' },
                email => { type => 'string' },
            },
        },
    },
}
