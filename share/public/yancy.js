
Vue.component('edit-field', {
    template: '#edit-field',
    props: {
        value: {
            required: true
        },
        schema: {
            type: 'object',
            required: true
        },
        required: {
            type: 'boolean',
            default: false
        },
        example: { }
    },
    data: function () {
        var fieldType = 'text',
            pattern = this.schema.pattern;

        if ( this.schema['enum'] ) {
            fieldType = 'select';
        }
        else if ( this.schema.type == 'boolean' ) {
            fieldType = 'checkbox';
        }
        else if ( this.schema.type == 'string' ) {
            if ( this.schema.format == 'email' ) {
                fieldType = 'email';
            }
            else if ( this.schema.format == 'url' ) {
                fieldType = 'url';
            }
            else if ( this.schema.format == 'tel' ) {
                fieldType = 'tel';
            }
            else if ( this.schema.format == 'password' ) {
                fieldType = 'password';
            }
            else if ( this.schema.format == 'date' ) {
                fieldType = 'date';
            }
            else if ( this.schema.format == 'date-time' ) {
                fieldType = 'datetime-local';
            }
        }
        else if ( this.schema.type == 'integer' || this.schema.type == 'number' ) {
            fieldType = 'number';
            if ( this.schema.type == 'integer' ) {
                pattern = this.schema.pattern || '^\\d+$';
            }
        }

        return {
            fieldType: fieldType,
            pattern: pattern,
            minlength: this.schema.minLength,
            maxlength: this.schema.maxLength,
            min: this.schema.minimum,
            max: this.schema.maximum,
            readonly: this.schema.readOnly,
            writeonly: this.schema.writeOnly,
            _value: this.value
        };
    },
    methods: {
        input: function () {
            this.$emit( 'input', this.$data._value );
        }
    },
    watch: {
        value: function () {
            this.$data._value = this.value;
        }
    }
});

Vue.component('item-form', {
    template: '#item-form',
    props: {
        item: {
            type: 'object',
            required: true
        },
        schema: {
            type: 'object',
            required: true
        },
        value: {
            required: true
        }
    },
    data: function () {
        return {
            _value: this.value ? JSON.parse( JSON.stringify( this.value ) ) : this.value,
            showRaw: false
        };
    },
    methods: {
        save: function () {
            this.$emit( 'input', this.$data._value );
            this.$data._value = JSON.parse( JSON.stringify( this.$data._value ) );
            this.$emit( 'close' );
        },
        cancel: function () {
            this.$data._value = JSON.parse( JSON.stringify( this.value ) );
            this.$emit( 'close' );
        },
        updateRaw: function (event) {
            this.$data._value = JSON.parse( event.target.value );
        },
        isRequired: function ( field ) {
            return this.schema.required && this.schema.required.indexOf( field ) >= 0;
        }
    },
    watch: {
        value: function () {
            this.$data._value = JSON.parse( JSON.stringify( this.value ) );
        }
    }
});

var app = new Vue({
    el: '#app',
    data: function () {
        var current = this.parseHash();
        return {
            currentCollection: current.collection || null,
            collections: {},
            openedRow: null,
            deleteIndex: null,
            addingItem: false,
            newItem: {},
            rows: [],
            columns: [],
            total: 0,
            currentPage: ( current.page ? parseInt( current.page ) : 0 ),
            perPage: 25,
            fetching: false
        }
    },
    methods: {
        toggleRow: function ( i ) {
            if ( this.openedRow == i ) {
                this.openedRow = null;
            }
            else {
                this.openedRow = i;
            }
        },

        fetchSpec: function () {
            var self = this;
            $.get( specUrl ).done( function ( data, status, jqXHR ) {
                self.parseSpec( data );
            } );
        },

        parseSpec: function ( spec ) {
            var pathParts = [], collectionName, collection, pathObj, firstCollection;
            this.collections = {};

            for ( var pathKey in spec.paths ) {
                pathObj = spec.paths[ pathKey ];

                pathParts = pathKey.split( '/' );
                collectionName = pathParts[1];
                collection = this.collections[ collectionName ];
                if ( !collection ) {
                    collection = this.collections[ collectionName ] = {
                        operations: { }
                    };
                }
                if ( !firstCollection ) {
                    firstCollection = collectionName;
                }

                // Array operations
                if ( pathParts.length == 2 ) {
                    if ( pathObj.get ) {
                        collection.operations["list"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.post ) {
                        collection.operations["add"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                }
                // Item operations
                else {
                    if ( pathObj.get ) {
                        collection.operations["get"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.put ) {
                        collection.operations["set"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                    if ( pathObj.delete ) {
                        collection.operations["delete"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ collectionName + 'Item' ]
                        };
                    }
                }
            }

            if ( this.currentCollection ) {
                this.fetchPage();
            }
            else {
                this.currentCollection = firstCollection;
            }
        },

        fetchPage: function () {
            if ( this.fetching ) return;
            var coll = this.collections[ this.currentCollection ],
                self = this,
                paging = {
                    limit: this.perPage,
                    offset: this.perPage * this.currentPage
                };
            this.fetching = true;
            $.get( coll.operations["list"].url, paging ).done(
                function ( data, status, jqXHR ) {
                    self.rows = data.rows;
                    self.total = data.total;
                    self.columns = coll.operations["list"].schema['x-list-columns'] || [];
                    self.fetching = false;
                    self.updateHash();
                }
            );
        },

        parseHash: function () {
            var parts = location.hash.split( '/' ),
                collection = parts[1],
                page = parts[2];
            return {
                collection: collection,
                page: page
            };
        },

        updateHash: function () {
            location.hash = "/" + this.currentCollection + "/" + this.currentPage;
        },

        saveItem: function (i) {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = JSON.stringify( this.rows[i] ),
                url = this.fillUrl( coll.operations['set'].url, this.rows[i] );
            $.ajax(
                {
                    url: url,
                    method: 'PUT',
                    data: value,
                    dataType: "json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.rows[i] = data;
                }
            );
        },

        addItem: function () {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = JSON.stringify( this.newItem ),
                url = coll.operations['add'].url;
            $.ajax(
                {
                    url: url,
                    method: 'POST',
                    data: value,
                    dataType: "json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.rows.unshift( data );
                    self.cancelAddItem();
                }
            );
        },

        showAddItem: function () {
            this.newItem = this.collections[ this.currentCollection ].operations['add'].schema.example;
            this.addingItem = true;
        },

        cancelAddItem: function () {
            this.addingItem = false;
            this.newItem = this.collections[ this.currentCollection ].operations['add'].schema.example;
        },

        confirmDeleteItem: function (i) {
            this.deleteIndex = i;
            $( '#confirmDelete' ).modal( 'show' );
        },

        cancelDeleteItem: function () {
            this.deleteIndex = null;
            $( '#confirmDelete' ).modal( 'hide' );
        },

        deleteItem: function () {
            var i = this.deleteIndex,
                self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-' + i ).val(),
                url = this.fillUrl( coll.operations['delete'].url, this.rows[i] );
            $.ajax(
                {
                    url: url,
                    method: 'DELETE',
                    data: value
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.cancelDeleteItem();
                    self.rows.splice(i,1);
                }
            ).fail(
                function ( jqXHR, status ) {
                    alert( "Failed: " + status );
                }
            );

        },

        fillUrl: function ( tmpl, data ) {
            return tmpl.replace( /\{([^}]+)\}/g, function ( match, field ) {
                return data[field];
            } );
        }

    },
    computed: {
        totalPages: function () {
            return Math.floor( this.total / this.perPage ) + 1;
        }
    },
    watch: {
        currentCollection: function () {
            this.data = [];
            this.currentPage = 0;
            this.fetchPage();
        },
        currentPage: function () {
            this.fetchPage();
        }
    },
    mounted: function () {
        this.fetchSpec();
    }
});

