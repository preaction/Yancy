
var app = new Vue({
    el: '#app',
    data: function () {
        return {
            currentCollection: null,
            collections: {},
            openedRow: null,
            deleteIndex: null,
            addingItem: false,
            rows: [],
            columns: [],
            total: 0,
            currentPage: 0,
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
            var pathParts = [], collectionName, collection, pathObj;
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

                this.currentCollection = "people"; // test
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
                }
            );
        },

        saveItem: function (i) {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-' + i ).val(),
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
                    self.toggleRow( i );
                }
            );
        },

        cancelSaveItem: function (i) {
            this.toggleRow( i );
        },

        addItem: function (i) {
            var self = this,
                coll = this.collections[ this.currentCollection ],
                value = $( '#data-add' ).val(),
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
            this.addingItem = true;
        },

        cancelAddItem: function () {
            this.addingItem = false;
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

