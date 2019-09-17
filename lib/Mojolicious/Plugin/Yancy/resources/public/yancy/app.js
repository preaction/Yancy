
Vue.component( 'upload-field', {
    template: '#upload-field',
    props: {
        name: {
            required: true
        },
        value: {
            required: true
        },
        disabled: {
            type: 'boolean',
            default: false
        },
    },
    data: function () {
        return { };
    },
    methods: {
        uploadFile: function (event) {
            var form = new FormData();
            form.append( 'upload', event.target.files[0] );
            $.ajax( {
                method: 'POST',
                url: location.pathname + '/upload',
                data: form,
                processData: false,
                contentType: false,
                context: this
            } )
            .then(
                function ( data ) {
                    this.$emit( 'input', data );
                }
            );
        },
    }
} );

Vue.component('edit-field', {
    template: '#edit-field',
    props: {
        name: {
            required: true
        },
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
        var schemaType, fieldType = 'text', inputMode = 'text', children = [],
            pattern = this.schema.pattern;

        if ( Array.isArray( this.schema.type ) ) {
            schemaType = this.schema.type[0];
        }
        else {
            schemaType = this.schema.type;
        }

        if ( this.schema['enum'] ) {
            fieldType = 'select';
        }
        else if ( schemaType == 'boolean' ) {
            fieldType = 'checkbox';
        }
        else if ( schemaType == 'string' ) {
            if ( this.schema.format == 'textarea' ) {
                fieldType = 'textarea';
            }
            else if ( this.schema.format == 'email' ) {
                fieldType = 'email';
                inputMode = 'email';
            }
            else if ( this.schema.format == 'url' ) {
                fieldType = 'url';
                inputMode = 'url';
            }
            else if ( this.schema.format == 'tel' ) {
                fieldType = 'tel';
                inputMode = 'tel';
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
            else if ( this.schema.format == 'filepath' ) {
                fieldType = 'file';
            }
        }
        else if ( schemaType == 'integer' || schemaType == 'number' ) {
            fieldType = 'number';
            inputMode = 'decimal';
            if ( schemaType == 'integer' ) {
                // Use pattern to show numeric input on iOS
                // https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/
                pattern = this.schema.pattern || '[0-9]*';
                inputMode = 'numeric';
            }
        }
        else if (schemaType == 'array') {
            fieldType = 'array';
            children = (this.value || []).map(function (v, ix) {
              return ({
                name: this.name + "-"+ix,
                example: this.schema.items.example,
                required: false, valid: this.valid,
                schema: this.schema.items,
                value: v
              })}, this);
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
            inputMode: inputMode,
            _value: this.value,
            showHtml: false,
            children: children
        };
    },
    methods: {
        input: function () {
            if(this.children.length){
                this.value = this.children.map(function(e){return e.value;}).filter(function(e){return e;});
                this.$data._value = this.value;
            }
            this.$emit( 'input', this.$data._value );
        },
        addChild: function () {
            this.children.push({
                name: this.name + "-"+(this.children.length+1),
                example: this.schema.items.example,
                required: false, valid: true,
                schema: this.schema.items
              });
        },
        removeChild: function (ix) {
            this.children.splice(ix,1);
        }
    },
    computed: {
        html: function () {
            return this.$data._value
                ? marked(this.$data._value, { sanitize: false })
                : '';
        }
    },
    watch: {
        value: function () {
            this.$data._value = this.value;
        },
        children: function() {
            this.value = this.children.map(function(e){return e.value;}).filter(function(e){return e;});
            this.$emit('input', this.value);
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

        _isEqual: function ( left, right ) {
            var fields = new Set( Object.keys( left ).concat( Object.keys( right ) ) );
            var isEqual = true;
            fields.forEach(function ( key ) {
                if ( !isEqual ) return;
                isEqual = ( left[ key ] == right[ key ] );
            });
            return isEqual;
        },

        cancel: function () {
            if ( !this._isEqual( this.$data._value, this.value ) ) {
                if ( !confirm( 'Changes will be lost' ) ) {
                    return;
                }
            }
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

var app = window.Yancy = new Vue({
    el: '#app',
    data: function () {
        var current = this.parseHash();
        return {
            hasSchema: null,
            currentSchemaName: current.schema || null,
            currentComponent: null,
            schema: {},
            openedRow: null,
            deleteIndex: null,
            addingItem: false,
            newItem: {},
            items: [],
            columns: [],
            total: 0,
            currentPage: ( current.page ? parseInt( current.page ) : 1 ),
            perPage: 25,
            fetching: false,
            error: {},
            formError: {},
            info: {},
            sortColumn: null,
            sortDirection: 1,
            newFilter: null,
            filters: [],
            toasts: []
        }
    },
    methods: {
        toggleRow: function ( i ) {
            if ( typeof i == 'undefined' || this.openedRow == i ) {
                this.$set( this, 'error', {} );
                this.$set( this, 'formError', {} );
                this.openedRow = null;
                this.openedOldValue = null;
            }
            else {
                this.addingItem = false;
                this.openedRow = i;
                this.openedOldValue = JSON.parse( JSON.stringify( this.items[i] ) );
            }
        },

        sortClass: function ( col ) {
            return this.sortColumn != col.field ? 'fa-sort'
                : this.sortDirection > 0 ? 'fa-sort-asc'
                : 'fa-sort-desc';
        },

        toggleSort: function ( col ) {
            if ( this.sortColumn == col.field ) {
                this.sortDirection = this.sortDirection > 0 ? -1 : 1;
            }
            else {
                this.sortColumn = col.field;
                this.sortDirection = 1;
            }
            this.currentPage = 1;
            this.fetchPage();
        },

        createFilter: function () {
            this.newFilter = {};
        },

        addFilter: function () {
            this.filters.push( this.newFilter );
            this.cancelFilter();
            this.fetchPage();
        },

        cancelFilter: function () {
            this.newFilter = null;
        },

        removeFilter: function ( i ) {
            this.filters.splice( i, 1 );
            this.fetchPage();
        },

        setSchema: function ( name ) {
            this.currentSchemaName = name;
            this.currentComponent = null;
            $( '#sidebar-collapse' ).collapse('hide');
        },

        setComponent: function ( name ) {
            this.currentComponent = name;
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
            var pathParts = [], schemaName, schema, pathObj, firstSchema;
            this.schema = {};
            this.hasSchema = false;

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
                    var seen = {}; // keep track of columns seen in list
                    definition[ 'x-list-columns' ] = [
                        definition[ 'x-id-field' ] || 'id', 'name', 'username', 'title', 'slug'
                    ].filter( function (x) {
                        if ( !seen[x] ) { seen[x] = 0 }
                        // do not allow duplicate columns, if for
                        // example the `x-id-field` is "name" or "username"
                        return !seen[x]++ && definition.properties[x];
                    } );
                    // Show a warning to the user if we think this
                    // guessed value for x-list-columns is kind of
                    // useless (a non-string field is probably not
                    // useful as a human identifier)
                    // XXX: We could write better heuristics for
                    // listable columns by finding the first 5-6 columns
                    // (by x-order) that aren't textarea strings or
                    // markdown strings.
                    // Or, we could add CSS to prevent long strings from
                    // breaking the table ("white-space: nowrap;
                    // text-overflow: ellipsis" would show only the
                    // first part of the first line of a large block of
                    // text.
                    if ( definition[ 'x-list-columns' ].length == 1
                        && definition.properties[ definition[ 'x-list-columns' ][0] ].type != 'string'
                    ) {
                        definition[ 'x-list-columns-guessed' ] = true;
                    }
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
                schemaName = pathParts[1];

                // Skip hidden schemas
                if ( spec.definitions[ schemaName ]['x-hidden'] ) {
                    continue;
                }

                schema = this.schema[ schemaName ];
                if ( !schema ) {
                    schema = this.schema[ schemaName ] = {
                        operations: { }
                    };
                }
                if ( !firstSchema ) {
                    firstSchema = schemaName;
                }
                this.hasSchema = true;

                // Array operations
                if ( pathParts.length == 2 ) {
                    if ( pathObj.get ) {
                        schema.operations["list"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ schemaName ]
                        };
                    }
                    if ( pathObj.post ) {
                        schema.operations["add"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ schemaName ]
                        };
                    }
                }
                // Item operations
                else {
                    if ( pathObj.get ) {
                        schema.operations["get"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ schemaName ]
                        };
                    }
                    if ( pathObj.put ) {
                        schema.operations["set"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ schemaName ]
                        };
                    }
                    if ( pathObj.delete ) {
                        schema.operations["delete"] = {
                            url: [ spec.basePath, pathKey ].join(''),
                            schema: spec.definitions[ schemaName ]
                        };
                    }
                }
            }

            if ( this.currentSchemaName && this.schema[ this.currentSchemaName ] ) {
                this.fetchPage();
            }
            else {
                this.currentSchemaName = firstSchema;
            }
        },

        fetchPage: function () {
            if ( this.fetching ) return;
            var self = this,
                query = {
                    $limit: this.perPage,
                    $offset: this.perPage * ( this.currentPage - 1 )
                };

            if ( this.sortColumn != null ) {
                var dir = this.sortDirection > 0 ? 'asc' : 'desc';
                query.$order_by = [ dir, this.sortColumn ].join( ':' );
            }
            for ( var i = 0; i < this.filters.length; i++ ) {
                query[ this.filters[i].field ] = this.filters[i].value;
            }

            this.fetching = true;
            delete this.error.fetchPage;
            $.get( this.currentOperations["list"].url, query ).done(
                function ( data, status, jqXHR ) {
                    if ( query.offset > data.total ) {
                        // We somehow got to a page that doesn't exist,
                        // so go to the first page instead
                        self.fetching = false;
                        self.currentPage = 1;
                        self.fetchPage();
                        return;
                    }

                    self.items = data.items;
                    self.total = data.total;
                    self.columns = self.getListColumns( self.currentSchemaName ),
                    self.fetching = false;
                    self.updateHash();
                }
            ).fail(
                function ( jqXHR, textStatus, errorThrown ) {
                    self.$set( self.error, 'fetchPage', errorThrown );
                }
            );
        },

        getListColumns: function ( schemaName ) {
            var schema = this.schema[ schemaName ].operations["list"].schema,
                props = schema.properties,
                columns = schema['x-list-columns'] || [];
            return columns.map( function (c) {
                if ( typeof c == 'string' ) {
                    return { title: props[ c ].title || c, field: c };
                }
                return c;
            } );
        },

        parseHash: function () {
            var parts = location.hash.split( '/' ),
                schema = parts[1],
                page = parts[2];
            return {
                schema: schema,
                page: page
            };
        },

        updateHash: function () {
            location.hash = "/" + this.currentSchemaName + "/" + this.currentPage;
        },

        saveItem: function (i) {
            var self = this,
                value = this.prepareSaveItem( this.items[i], this.currentOperations['set'].schema ),
                url = this.fillUrl( this.currentOperations['set'].url, this.openedOldValue );
            delete this.error.saveItem;
            this.$set( this, 'formError', {} );
            $.ajax(
                {
                    url: url,
                    method: 'PUT',
                    data: value,
                    dataType: "json",
                    contentType: "application/json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.items[i] = data;
                    self.toggleRow( i );
                    self.addToast( { icon: "fa-save", title: "Saved", text: "Item saved" } );
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
                schema = this.currentSchema,
                value = this.prepareSaveItem( this.newItem, schema ),
                url = this.currentOperations['add'].url;
            delete this.error.addItem;
            this.$set( this, 'formError', {} );
            $.ajax(
                {
                    url: url,
                    method: 'POST',
                    data: value,
                    dataType: "json",
                    contentType: "application/json"
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.items.unshift( data );
                    self.total++;
                    self.cancelAddItem();
                    self.addToast( { icon: "fa-save", title: "Added", text: "Item added" } );
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
            for ( var k in schema.properties ) {
                var prop = schema.properties[k];
                if ( prop.readOnly ) {
                    delete copy[k];
                }
                else if (
                    ( prop.type == 'boolean' || prop.type[0] == 'boolean' )
                    && !copy[k]
                ) {
                    copy[k] = false;
                }
                else if ( prop.format == 'markdown' ) {
                    if ( prop['x-html-field'] ) {
                        copy[ prop['x-html-field'] ]
                            = marked( copy[k], { sanitize: false });
                    }
                }
            }
            return JSON.stringify( copy );
        },

        showAddItem: function () {
            if ( this.addingItem ) {
                this.cancelAddItem();
                return;
            }
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
            var schema = this.currentSchema,
                item = {};
            for ( var k in schema.properties ) {
                item[k] = schema.properties[k].default === undefined ? null : schema.properties[k].default;
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
                schema = this.currentSchema,
                value = $( '#data-' + i ).val(),
                url = this.fillUrl( this.currentOperations['delete'].url, this.items[i] );
            $.ajax(
                {
                    url: url,
                    method: 'DELETE',
                    data: value
                }
            ).done(
                function ( data, status, jqXHR ) {
                    self.cancelDeleteItem();
                    self.items.splice(i,1);
                }
            ).fail(
                function ( jqXHR, status ) {
                    alert( "Failed: " + status );
                }
            );

        },

        gotoPage: function ( page ) {
            this.currentPage = page;
            window.scrollTo( 0, 0 );
        },

        fillUrl: function ( tmpl, data ) {
            return tmpl.replace( /\{([^}]+)\}/g, function ( match, field ) {
                if ( !data[field].replace ) {
                    // This must not be a string, so we can't escape it...
                    return data[field];
                }
                // This works the same as Mojo::Util xml_escape
                return data[field].replace( /[&<>"']/g, function ( match ) {
                    switch ( match ) {
                        case '&': return '&amp;';
                        case '<': return '&lt;';
                        case '>': return '&gt;';
                        case '"': return '&quot;';
                        case "'": return '&#039;';
                    }
                } );
            } );
        },

        renderValue: function ( field, value ) {
            var schema = this.currentSchema;
            var fieldType = schema.properties[ field ].type;
            var type = Array.isArray( fieldType ) ? fieldType[0] : fieldType;
            if ( type == 'boolean' ) {
                return value ? 'Yes' : 'No';
            }
            return value;
        },

        rowViewUrl: function ( data ) {
            return this.fillUrl( this.currentSchema[ 'x-view-item-url' ], data );
        },

        addToast: function ( toast ) {
            var self = this;
            this.toasts.push( toast );
            setTimeout(
                function ( toast ) { self.removeToast( toast ) },
                5000,
                toast
            );
        },

        removeToast: function ( toast ) {
            this.toasts.splice( this.toasts.indexOf( toast ), 1 );
        }

    },
    computed: {
        totalPages: function () {
            var mod = this.total % this.perPage,
                pages = this.total / this.perPage,
                totalPages = mod == 0 ? pages : Math.floor( pages ) + 1;
            return totalPages;
        },

        pagerPages: function () {
            var totalPages = this.totalPages,
                currentPage = this.currentPage,
                pages = [];
            if ( totalPages < 10 ) {
                for ( var i = 1; i <= totalPages; i++ ) {
                    pages.push( i );
                }
                return pages;
            }
            var minPage = currentPage > 4 ? currentPage - 4 : 1,
                maxPage = minPage + 8 < totalPages ? minPage + 8 : totalPages;
            for ( var i = minPage; i <= maxPage; i++ ) {
                pages.push( i );
            }
            return pages;
        },

        currentOperations: function () {
            return this.schema[ this.currentSchemaName ] ? this.schema[ this.currentSchemaName ].operations : {};
        },
        currentSchema: function () {
            return this.currentOperations.get ? this.currentOperations.get.schema : {};
        }
    },
    watch: {
        currentSchemaName: function () {
            this.data = [];
            this.currentPage = 1;
            this.openedRow = null;
            this.addingItem = false;
            this.fetching = false;
            this.sortColumn = null;
            this.sortDirection = 1;
            this.filters = [];
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

