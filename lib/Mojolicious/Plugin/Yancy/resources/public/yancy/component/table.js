/**
 * TODO: Find documentation format for these components and generate
 * HTML from them for the website
 * TODO: If src is the current URL, use the History API to change the
 * location to include query params we're using
 */
Vue.component( 'yancy-table', {
    template: '#yancy-component-table',
    props: {
        /**
         * The columns to display. Like x-list-columns.
         */
        columns: {
            type: Array,
            required: true
        },
        /**
         * The URL to fetch items from. Must be routed to a Yancy
         * list or feed action. Defaults to the current URL.
         *
         * This component will send an Accept header for
         * application/json, to allow for content negotiation.
         *
         */
        src: {
            type: String,
            default: window.location.href
        },
        /**
         * How many items to display on the page. Defaults to 10.
         */
        limit: {
            type: Number,
            default: 10
        },
    },
    data: function () {
        return {
            items: [],
            totalPages: 0,
            page: 1,
            sortColumn: null,
            sortDirection: 1,
            fetching: false,
            error: ''
        };
    },
    mounted: function () {
        if ( this.src.match( /^wss?:/ ) ) {
            this.ws = new WebSocket( this.src );
            this.ws.onmessage = ( msg ) => this.handleMessage( msg );
        }
        else {
            this.fetchPage( this.page );
        }
    },
    methods: {
        handleMessage: function ( msg ) {
            let res = JSON.parse( msg.data );
            if ( res.method == 'list' ) {
                this.items = res.items;
                this.page = Math.floor( res.offset / res.limit ) + 1;
                this.totalPages = Math.ceil( res.total / res.limit );
            }
            else if ( res.method == 'delete' ) {
                this.items.splice( res.index, 1 );
            }
            else if ( res.method == 'create' ) {
                this.items.splice( res.index, 0, res.item );
            }
            else if ( res.method == 'set' ) {
                for ( let k in res.item ) {
                    this.items[ res.index ][ k ] = res.item[ k ];
                }
            }
        },

        fetchPage: function ( page ) {
            if ( this.fetching ) return;
            this.fetching = true;
            this.page = page;
            this.error = '';

            var query = { };

            // First add any query parameters already on the page, to
            // preserve search queries
            for ( const [ key, value ] of (new URL(document.location)).searchParams ) {
                query[ key ] = value;
            }

            // Now add the parameters for this page of results
            query.$limit = this.limit;
            query.$offset = this.limit * ( this.page - 1 );
            if ( this.sortColumn != null ) {
                var dir = this.sortDirection > 0 ? 'asc' : 'desc';
                query.$order_by = [ dir, this.sortColumn ].join( ':' );
            }

            $.ajax({
                context: this,
                url: this.src,
                data: query,
                dataType: 'json',
                success: function ( data, status, jqXHR ) {
                    if ( query.$offset > data.total ) {
                        // We somehow got to a page that doesn't exist,
                        // so go to the first page instead
                        this.fetching = false;
                        this.fetchPage(1);
                        return;
                    }

                    this.$set( this, 'items', data.items );
                    this.totalPages = Math.ceil( data.total / this.limit );
                    this.fetching = false;
                },
                error: function ( jqXHR, textStatus, errorThrown ) {
                    this.fetching = false;
                    this.error = errorThrown;
                }
            });
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
            this.fetchPage(1);
        },

        fillTemplate: function ( tmpl, data ) {
            return tmpl.replace( /\{([^\}]+)\}/g, function ( match, field ) {
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

    },

    computed: {

        _columns: function () {
            return this.columns.map( function (c) {
                return typeof c == 'string' ? { field: c } : c;
            } );
        },

        pager: function () {
            var totalPages = this.totalPages,
                page = this.page,
                pages = [];
            if ( totalPages < 10 ) {
                for ( var i = 1; i <= totalPages; i++ ) {
                    pages.push( i );
                }
                return pages;
            }
            var minPage = page > 4 ? page - 4 : 1,
                maxPage = minPage + 8 < totalPages ? minPage + 8 : totalPages;
            for ( var i = minPage; i <= maxPage; i++ ) {
                pages.push( i );
            }
            return pages;
        },
    },

} );
