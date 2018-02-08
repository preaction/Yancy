
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
        valid: {
            type: 'boolean',
            default: true
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
            else if ( this.schema.format == 'markdown' ) {
                fieldType = 'markdown';
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
    computed: {
        html: function () {
            return this.$data._value
                ? marked(this.$data._value, { sanitize: true })
                : '';
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
        },
        showReadOnly: {
            required: false,
            default: true
        },
        error: {
            default: { }
        }
    },
    data: function () {
        return {
            _value: this.value ? JSON.parse( JSON.stringify( this.value ) ) : this.value,
            showRaw: false,
            rawValue: null,
            rawError: null
        };
    },
    methods: {
        save: function () {
            if ( this.showRaw && this.rawError ) { return; }
            this.$emit( 'input', this.$data._value );
            this.$data._value = JSON.parse( JSON.stringify( this.$data._value ) );
        },

        cancel: function () {
            this.$data._value = JSON.parse( JSON.stringify( this.value ) );
            this.$emit( 'close' );
        },

        updateRaw: function () {
            this.rawError = null;
            try {
                this.$data._value = JSON.parse( this.rawValue );
            }
            catch (e) {
                this.rawError = e;
            }
        },

        isRequired: function ( field ) {
            return this.schema.required && this.schema.required.indexOf( field ) >= 0;
        }
    },
    computed: {
        properties: function () {
            var props = [], schema = this.schema;
            for ( var key in schema.properties ) {
                var prop = schema.properties[ key ];
                var defaults = { name: key };
                if ( prop[ 'x-hidden' ] || ( prop['readOnly'] && !this.showReadOnly ) ) {
                    continue;
                }
                if ( typeof prop['x-order'] == 'undefined' ) {
                    defaults['x-order'] = 999999;
                }
                if ( !prop.title ) {
                    defaults.title = key;
                }
                props.push( Object.assign( defaults, prop ) );
            }
            return props.sort( function (a, b) {
                return a['x-order'] < b['x-order'] ? -1
                    : a['x-order'] > b['x-order'] ?  1
                    : a.name < b.name ? -1
                    : a.name > b.name ? 1
                    : 0;
            } );
        },
        example: function () {
            return this.schema.example || {};
        }
    },
    watch: {
        value: function () {
            this.$data._value = JSON.parse( JSON.stringify( this.value ) );
        },
        showRaw: function () {
            this.rawError = null;
            this.rawValue = JSON.stringify( this.$data._value, null, 4 );
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
            fetching: false,
            error: {},
            formError: {},
            info: {}
        }
    },
    methods: {
        toggleRow: function ( i ) {
            if ( typeof i == 'undefined' || this.openedRow == i ) {
                this.$set( this, 'error', {} );
                this.$set( this, 'formError', {} );
                this.openedRow = null;
            }
            else {
                this.addingItem = false;
                this.openedRow = i;
            }
        },

        fetchSpec: function () {
            var self = this;
            delete self.error.fetchSpec;
            $.get( specUrl ).done( function ( data, status, jqXHR ) {
                self.parseSpec( data );
            } ).fail( function ( jqXHR, textStatus, errorThrown ) {
                self.$set( self.error, 'fetchSpec', errorThrown );
            } );
        },

        parseSpec: function ( spec ) {
            var pathParts = [], collectionName, collection, pathObj, firstCollection;
            this.collections = {};

            // Preprocess definitions
            for ( var defKey in spec.definitions ) {
                var definition = spec.definitions[ defKey ];
                if ( definition.type != 'object' ) {
                    continue;
                }
                if ( !definition.properties ) {
                    continue;
                }

                if ( !definition[ 'x-list-columns' ] ) {
                    definition[ 'x-list-columns' ] = [
                        'id', 'name', 'username', 'title', 'slug'
                    ].filter( function (x) {
                        return !!definition.properties[x];
                    } );
                }

                for ( var propKey in definition.properties ) {
                    var prop = definition.properties[ propKey ];
                    if ( prop[ 'x-html-field' ] ) {
                        definition.properties[ prop['x-html-field' ] ][ 'x-hidden' ] = true;
                    }
                }
            }

            for ( var pathKey in spec.paths ) {
                pathObj = spec.paths[ pathKey ];

                pathParts = pathKey.split( '/' );
                collectionName = pathParts[1];

                // Skip hidden collections
                if ( spec.definitions[ collectionName + 'Item' ]['x-hidden'] ) {
                    continue;
                }

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
            delete this.error.fetchPage;
            $.get( coll.operations["list"].url, paging ).done(
                function ( data, status, jqXHR ) {
                    self.rows = data.rows;
                    self.total = data.total;
                    self.columns = coll.operations["list"].schema['x-list-columns'] || [];
                    self.fetching = false;
                    self.updateHash();
                }
            ).fail(
                function ( jqXHR, textStatus, errorThrown ) {
                    self.$set( self.error, 'fetchPage', errorThrown );
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
                value = this.prepareSaveItem( this.rows[i], coll.operations['set'].schema ),
                url = this.fillUrl( coll.operations['set'].url, this.rows[i] );
            delete this.error.saveItem;
            this.$set( this, 'formError', {} );
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
                    self.toggleRow( i );
                    self.$set( self.info, 'saveItem', true );
                    setTimeout( function () {
                        self.$set( self.info, 'saveItem', false );
                    }, 5000 );
                }
            ).fail(
                function ( jqXHR, textStatus, errorThrown ) {
                    if ( jqXHR.responseJSON ) {
                        self.parseErrorResponse( jqXHR.responseJSON );
                        self.$set( self.error, 'saveItem', 'Data validation failed' );
                    }
                    else {
                        self.$set( self.error, 'saveItem', jqXHR.responseText );
                    }
                }
            );
        },

        addItem: function () {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = this.prepareSaveItem( this.newItem, coll.operations['add'].schema ),
                url = coll.operations['add'].url;
            delete this.error.addItem;
            this.$set( this, 'formError', {} );
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
                    self.$set( self.info, 'addItem', true );
                    setTimeout( function () {
                        self.$set( self.info, 'addItem', false );
                    }, 5000 );
                }
            ).fail(
                function ( jqXHR, textStatus, errorThrown ) {
                    if ( jqXHR.responseJSON ) {
                        self.parseErrorResponse( jqXHR.responseJSON );
                        self.$set( self.error, 'addItem', 'Data validation failed' );
                    }
                    else {
                        self.$set( self.error, 'addItem', jqXHR.responseText );
                    }
                }
            );
        },

        parseErrorResponse: function ( resp ) {
            for ( var i = 0; i < resp.errors.length; i++ ) {
                var error = resp.errors[ i ],
                    pathParts = error.path.split( /\// ),
                    field = pathParts[2],
                    message = error.message;
                this.$set( this.formError, field, message );
            }
        },

        prepareSaveItem: function ( item, schema ) {
            var copy = JSON.parse( JSON.stringify( item ) );
            for ( var k in copy ) {
                if ( schema.properties[k].readOnly ) {
                    delete copy[k];
                }
                else if ( schema.properties[k].format == 'markdown' ) {
                    if ( schema.properties[k]['x-html-field'] ) {
                        copy[ schema.properties[k]['x-html-field'] ]
                            = marked( copy[k], { sanitize: true });
                    }
                }
                else if ( copy[k] === null ) {
                    // `null` doesn't pass type checks, and Perl doesn't
                    // distinguish between `undef` and `defined but no
                    // value` in an object, so make this field `undef`
                    // to Perl
                    delete copy[k];
                }
            }
            return JSON.stringify( copy );
        },

        showAddItem: function () {
            this.toggleRow();
            this.newItem = this.createBlankItem();
            this.addingItem = true;
        },

        cancelAddItem: function () {
            this.$set( this, 'formError', {} );
            this.addingItem = false;
            this.newItem = this.createBlankItem();
        },

        createBlankItem: function () {
            var schema = this.collections[ this.currentCollection ].operations['add'].schema,
                item = {};
            if ( schema.example ) {
                return schema.example;
            }
            for ( var k in schema.properties ) {
                item[k] = null;
            }
            return item;
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
        },
        operations: function () {
            return this.collections[ this.currentCollection ].operations;
        },
        schema: function () {
            return this.collections[ this.currentCollection ].operations.get.schema || {};
        }
    },
    watch: {
        currentCollection: function () {
            this.data = [];
            this.currentPage = 0;
            this.openedRow = null;
            this.addingItem = false;
            this.fetching = false;
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

