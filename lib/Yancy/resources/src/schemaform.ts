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
        input.setAttribute( "name", propName );
        input.schema = prop;
        this._root.appendChild( input );
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

