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
         * list action. Defaults to the current URL.
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
        this.fetchPage( this.page );
    },
    methods: {
        fetchPage: function ( page ) {
            if ( this.fetching ) return;
            this.fetching = true;
            this.page = page;
            this.error = '';

            var query = {
                    $limit: this.limit,
                    $offset: this.limit * ( this.page - 1 )
                };

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
                    console.log( 'Got data from ' + this.src );
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

