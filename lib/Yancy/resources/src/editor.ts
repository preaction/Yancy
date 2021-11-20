
import TabView from './tabview';
import SchemaForm from './schemaform';
import SchemaList from './schemalist';
import html from './editor.html';
export default class Editor extends HTMLElement {

  schema: any;
  root: string;

  constructor() {
    super();

    window.customElements.define( 'tab-view', TabView );
    window.customElements.define( 'schema-form', SchemaForm );
    window.customElements.define( 'schema-list', SchemaList );
  }

  get tabView() {
    return this.querySelector('tab-view') as TabView;
  }

  get schemaMenu() {
    return this.querySelector('#schema-menu');
  }

  connectedCallback() {
    this.innerHTML = html.trim();
    this.schemaMenu.addEventListener('click', (e) => this.clickSchema(e));

    // Show welcome pane
    let hello = document.createElement('div');
    hello.appendChild( document.createTextNode( 'Hello, World!' ) );
    this.tabView.addTab("Hello", hello);

    // Add schema menu
    for ( let schemaName of Object.keys(this.schema).sort() ) {
      let li = document.createElement( 'li' );
      li.dataset["schema"] = schemaName;
      li.appendChild( document.createTextNode( schemaName ) );
      this.schemaMenu.appendChild( li );
    }
  }

  clickSchema(e:Event) {
    let schemaName = (<HTMLElement>e.target).dataset["schema"];
    // Find the schema's tab or open one
    if ( this.tabView.showTab( schemaName ) ) {
      return;
    }

    let pane = document.createElement( 'div' );

    let toolbar = document.createElement( 'div' );
    let createBtn = document.createElement( 'button' );
    createBtn.appendChild( document.createTextNode( 'Create' ) );
    createBtn.addEventListener( 'click', e => this.clickCreateButton(e, schemaName) );
    createBtn.dataset["create"] = "";
    toolbar.appendChild( createBtn );
    pane.appendChild( toolbar );

    let list = document.createElement( 'schema-list' ) as SchemaList;
    list.schema = this.schema[ schemaName ];
    list.url = this.root + schemaName;
    // XXX: Add event listener to show edit form
    pane.appendChild( list );

    // XXX: Only create new tabs if Ctrl or Command are held
    this.tabView.addTab( schemaName, pane );
  }

  clickCreateButton(e:Event, schemaName:string) {
    if ( this.tabView.showTab( schemaName + "-create" ) ) {
      return;
    }

    let editForm = document.createElement( 'schema-form' ) as SchemaForm;
    editForm.schema = this.schema[ schemaName ];
    editForm.url = this.root + schemaName;
    editForm.method = "POST";
    // XXX: Add event listener to close tab after save or cancel
    // XXX: Only create new tabs if Ctrl or Command are held
    this.tabView.addTab( schemaName + "-create", editForm );
  }
}

