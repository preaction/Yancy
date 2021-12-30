
import { SchemaProperty } from './schema'
export default class SchemaList extends HTMLElement {

  url: string;
  schema: { properties: {[index:string]:SchemaProperty} };

  connectedCallback() {
    if ( this.url ) {
      this.refresh();
    }
  }

  async refresh() {
    // XXX: Create Yancy fetch utility?
    const res = await fetch( this.url, { headers: { Accept: 'application/json' } } ).then( r => r.json() ) as { items: Array<{[index:string]:any}>, total: Number };
    const columns = Object.keys( this.schema.properties ).sort(
      (a, b) => {
        const ap = this.schema.properties[a];
        const bp = this.schema.properties[b];
        if ( ap['x-order'] < bp['x-order'] ) {
          return -1;
        }
        else if ( ap['x-order'] > bp['x-order'] ) {
          return 1;
        }
        return a < b ? -1 : a > b ? 1 : 0;
    });

    const table = document.createElement('table');
    // XXX: Table header
    // XXX: Filtering
    const tbody = table.appendChild( document.createElement( 'tbody' ) );
    for ( const item of res.items ) {
      const tr = tbody.appendChild( document.createElement('tr') );
      for ( const col of columns ) {
        const td = tr.appendChild( document.createElement('td') );
        td.appendChild( document.createTextNode( item[col] ) );
      }
    }

    // XXX: Pagination

    this.replaceChildren( table );
  }
}
