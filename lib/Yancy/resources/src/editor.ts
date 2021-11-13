
import TabView from './tabview';
import SchemaForm from './schemaform';
import html from './editor.html';
export default class Editor extends HTMLElement {

  schema: any
  constructor() {
    super();

    window.customElements.define( 'tab-view', TabView );
    window.customElements.define( 'schema-form', SchemaForm );
  }

  get tabView() {
    return this.querySelector('tab-view') as TabView;
  }

  get schemaList() {
    return this.querySelector('#schema-list');
  }

  connectedCallback() {
    this.innerHTML = html.trim();
    this.schemaList.addEventListener('click', (e) => this.clickSchema(e));

    // Show welcome pane
    let hello = document.createElement('div');
    hello.appendChild( document.createTextNode( 'Hello, World!' ) );
    this.tabView.addTab("Hello", hello);

    // Add schema list
    for ( let schemaName of Object.keys(this.schema).sort() ) {
      let li = document.createElement( 'li' );
      li.dataset["schema"] = schemaName;
      li.appendChild( document.createTextNode( schemaName ) );
      this.schemaList.appendChild( li );
    }
  }

  clickSchema(e:Event) {
    let schemaName = (<HTMLElement>e.target).dataset["schema"];
    // Find the schema's tab or open one
    if ( this.tabView.showTab( schemaName ) ) {
      return;
    }
    let editForm = document.createElement( 'schema-form' ) as SchemaForm;
    editForm.schema = this.schema[ schemaName ];
    this.tabView.addTab( schemaName, editForm );
  }
}

