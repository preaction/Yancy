
import TabView from './tabview';
import html from './editor.html';
export default class Editor extends HTMLElement {

  schema: Object
  constructor() {
    super();

    customElements.define( 'tab-view', TabView );

    const shadow = this.attachShadow({mode: 'open'});
    shadow.innerHTML = html.trim();

    this.schemaList.addEventListener('click', (e) => this.clickSchema(e));
  }

  get tabView() {
    return this.shadowRoot.querySelector('tab-view') as TabView;
  }

  get schemaList() {
    return this.shadowRoot.querySelector('#schema-list');
  }

  connectedCallback() {
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
    console.log( `Clicked schema ${schemaName}` );
  }
}

