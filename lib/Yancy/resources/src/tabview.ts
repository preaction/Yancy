
import html from './tabview.html';
export default class TabView extends HTMLElement {

  constructor() {
    super();

    const shadow = this.attachShadow({mode: 'open'});
    shadow.innerHTML = html.trim();

    this.tabBar.addEventListener('click', (e) => this.clickTab(e));
  }

  get tabBar() {
    return this.shadowRoot.querySelector( '#tab-bar' );
  }
  get tabPanes() {
    return this.shadowRoot.querySelector( '#tab-pane' );
  }

  addTab( label: string, content: HTMLElement ) {
    const li = document.createElement( 'li' );
    li.appendChild( document.createTextNode( label ) );
    this.tabBar.appendChild( li );
    this.tabPanes.appendChild( content );
    console.log( "Activating..." );
    this.showTab(this.tabBar.children.length-1);
  }

  showTab( tabIndex: number ) {
    if ( this.tabBar.querySelector( '.active' ) ) {
      this.tabBar.querySelector( '.active' ).classList.remove( 'active' );
      this.tabPanes.querySelector( '.active' ).classList.remove( 'active' );
    }
    this.tabBar.children[tabIndex].classList.add('active');
    this.tabPanes.children[tabIndex].classList.add('active');
  }

  clickTab( e: Event ) {
  }
}

