import { marked } from 'marked';
import { SchemaObject } from './schema'
import { SchemaInput, SchemaInputClass } from './schemainput';

export default class SchemaForm extends HTMLElement {

  method: string;
  url: string;
  static _inputTypes: { [index: string]: SchemaInputClass } = {};
  static _inputOrder: string[] = [];
  _schema: SchemaObject;
  _root: DocumentFragment;

  constructor() {
    super();
    // This document fragment allows us to build the form before
    // anything is added to the page DOM
    this._root = document.createDocumentFragment();
  }

  static addInputType( ft: SchemaInputClass ) {
    const tagName = ft.register();
    SchemaForm._inputOrder.unshift( tagName );
    SchemaForm._inputTypes[ tagName ] = ft;
  }

  set schema(newSchema: any) {
    if ( this._schema ) {
      // XXX: Remove existing inputs
    }
    if ( newSchema.properties ) {
      // XXX: Move to "object field" input type
      for ( const propName in newSchema.properties ) {
        const prop = newSchema.properties[ propName ];
        const inputTag = SchemaForm._inputOrder.find(
          tagName => SchemaForm._inputTypes[ tagName ].handles( prop )
        );
        if ( !inputTag ) {
          throw new Error( `Could not find input to handle prop: ${JSON.stringify(prop)}` );
        }
        const input = document.createElement( inputTag ) as SchemaInput;
        input.name = propName;
        input.schema = prop;
        input.required = newSchema.required?.indexOf( propName ) >= 0;
        input.setAttribute( 'aria-labelledby', `input-${propName}-label` );
        input.setAttribute( 'aria-describedby', `input-${propName}-desc` );
        input.setAttribute( 'id', `input-${propName}` );

        const field = document.createElement( 'div' );
        field.setAttribute( "name", propName );
        // <label>
        const label = document.createElement( 'label' );
        label.setAttribute( 'id', `input-${propName}-label` );
        label.setAttribute( 'for', `input-${propName}` );
        label.appendChild( document.createTextNode( prop.title || propName ) );
        // Since the `for` attribute doesn't point to an input element,
        // the default focus behavior doesn't work. Instead, we have to
        // do it ourselves...
        label.addEventListener(
          'click',
          event => {
            const firstFocusableElement = input.querySelector( 'input,textarea,select,[tabindex]' ) as HTMLElement;
            firstFocusableElement.focus();
            event.preventDefault();
          },
        );
        // <small> for description
        const desc = document.createElement( 'small' );
        desc.setAttribute( 'id', `input-${propName}-desc` );
        desc.innerHTML = marked.parse( prop.description || '' );
        // XXX: <div> for validation error

        // XXX: HTML should be fetched from the app at runtime so that
        // it can be overridden by the user.

        field.appendChild( label );
        field.appendChild( input );
        field.appendChild( desc );
        this._root.appendChild( field );
      }
    }
    this._schema = newSchema;

    const toolbar = document.createElement( 'div' );
    toolbar.classList.add( 'form-toolbar' );
    this._root.appendChild( toolbar );
    const saveBtn = document.createElement( 'button' );
    saveBtn.appendChild( document.createTextNode( 'Save' ) );
    saveBtn.addEventListener( 'click', e => this.submit() );
    saveBtn.setAttribute( 'name', 'submit' );
    toolbar.appendChild( saveBtn );
    const cancelBtn = document.createElement( 'button' );
    cancelBtn.appendChild( document.createTextNode( 'Cancel' ) );
    cancelBtn.addEventListener( 'click', e => this.cancel() );
    cancelBtn.setAttribute( 'name', 'cancel' );
    toolbar.appendChild( cancelBtn );
  }

  schemaFor( propName: string ) {
    return this._schema.properties[propName];
  }

  get _allInputs(): SchemaInput[] {
    const types = SchemaForm._inputOrder.join( ',' );
    return [ ... this.querySelectorAll( types ) ] as SchemaInput[];
  }

  set value(newValue: any) {
    const inputs = this._allInputs;
    for ( let propName in newValue ) {
      let input = inputs.find( i => i.name === propName );
      input.value = newValue[ propName ];
    }
  }

  get value(): any {
    let val = {} as any;
    for ( const input of this._allInputs ) {
      if ( input.value === null ) {
        continue;
      }
      val[ input.name ] = input.value;
    }
    return val;
  }

  connectedCallback() {
    this.appendChild( this._root );
  }

  async submit() {
    const req = {
      method: this.method,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify( this.value ),
    };
    const res = await fetch( this.url, req ).then( r => r.json(), r => r.json() );
    if ( res.errors ) {
      this.showErrors( res.errors );
      return;
    }
    // XXX: Emit event with new data
  }

  cancel() {
  }

  showErrors( errors:Array<{message: string, path?: string}> ) {
    this.querySelector( 'ul.errors' )?.remove();
    const ul = document.createElement( 'ul' );
    ul.classList.add( 'errors' );
    this.insertBefore( ul, this.firstChild );
    for ( let err of errors ) {
      const li = ul.appendChild( document.createElement( 'li' ) );
      const msg = err.path ? `${err.path}: ${err.message}` : err.message;
      li.append(msg);
      if ( err.path ) {
        // XXX: Mark field as errored
      }
    }
  }
}

import TextInput from './schemainput/textinput';
SchemaForm.addInputType( TextInput );

