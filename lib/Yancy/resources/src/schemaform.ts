import { marked } from 'marked';
import { SchemaProperty } from './schema'
import { SchemaInput, SchemaInputClass } from './schemainput';

export default class SchemaForm extends HTMLElement {

  static _inputTypes: { [index: string]: SchemaInputClass } = {};
  static _inputOrder: string[] = [];
  _schema: Object;
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
      // Remove existing inputs
    }
    if ( newSchema.properties ) {
      for ( const propName in newSchema.properties ) {
        const prop = newSchema.properties[ propName ];
        const inputTag = SchemaForm._inputOrder.find(
          tagName => SchemaForm._inputTypes[ tagName ].handles( prop )
        );
        if ( !inputTag ) {
          throw new Error( `Could not find input to handle prop: ${JSON.stringify(prop)}` );
        }
        const input = document.createElement( inputTag ) as SchemaInput;
        input.schema = prop;
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
    // XXX: Handle array types
    this._schema = newSchema;
  }

  set value(newValue: any) {
    for ( let propName in newValue ) {
      let input = this.querySelector( `[name=${propName}]` ) as SchemaInput;
      input.value = newValue[ propName ];
    }
  }

  get value(): any {
    let val = {} as any;
    for ( const el of this._root.children ) {
      const input = el as SchemaInput;
      val[ input.name ] = input.value;
    }
    return val;
  }

  connectedCallback() {
    this.appendChild( this._root );
  }

}

import TextInput from './schemainput/textinput';
SchemaForm.addInputType( TextInput );

