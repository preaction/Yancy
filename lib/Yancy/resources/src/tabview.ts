
import html from './tabview.html';
export default class TabView extends HTMLElement {

  get tabBar() {
    return this.querySelector( '#tab-bar' );
  }
  get tabPanes() {
    return this.querySelector( '#tab-pane' );
  }
  get tabs(): Array<HTMLElement> {
    return Array.from(this.tabBar.children) as Array<HTMLElement>;
  }

  connectedCallback() {
    this.innerHTML = html.trim();
    this.tabBar.addEventListener('click', (e) => this.clickTab(e));
  }

  addTab( label: string, content: HTMLElement ) {
    const li = document.createElement( 'li' );
    li.appendChild( document.createTextNode( label ) );
    this.tabBar.appendChild( li );
    this.tabPanes.appendChild( content );
    this.showTab(label);
  }

  showTab( label: string ) : boolean {
    let idx = this.tabs.findIndex( el => el.innerText == label );
    if ( idx < 0 ) {
      console.log( `Could not find tab with label ${label}` );
      return false;
    }
    if ( this.tabBar.querySelector( '.active' ) ) {
      this.tabBar.querySelector( '.active' ).classList.remove( 'active' );
      this.tabPanes.querySelector( '.active' ).classList.remove( 'active' );
    }
    this.tabBar.children[idx].classList.add('active');
    this.tabPanes.children[idx].classList.add('active');
    return true;
  }

  clickTab( e: Event ) {
  }

  removeTab( label: string ) {
    let idx = this.tabs.findIndex( el => el.innerText == label );
    if ( idx < 0 ) {
      console.log( `Could not find tab with label ${label}` );
      return false;
    }
    this.tabBar.children[idx].remove();
    this.tabPanes.children[idx].remove();
    this.showTab( this.tabs[idx-1].innerText );
  }
}

