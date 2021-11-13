import { SchemaProperty } from './schema'
import { SchemaField, SchemaFieldClass } from './schemafield';

export default class SchemaForm extends HTMLElement {

  static _fieldTypes: { [index: string]: SchemaFieldClass } = {};
  static _fieldOrder: string[] = [];
  _schema: Object;
  _root: DocumentFragment;

  constructor() {
    super();
    // This document fragment allows us to build the form before
    // anything is added to the page DOM
    this._root = document.createDocumentFragment();
  }

  static addFieldType( ft: SchemaFieldClass ) {
    const tagName = ft.register();
    SchemaForm._fieldOrder.unshift( tagName );
    SchemaForm._fieldTypes[ tagName ] = ft;
  }

  set schema(newSchema: any) {
    if ( this._schema ) {
      // Remove existing fields
    }
    if ( newSchema.properties ) {
      for ( const propName in newSchema.properties ) {
        const prop = newSchema.properties[ propName ];
        const fieldTag = SchemaForm._fieldOrder.find(
          tagName => SchemaForm._fieldTypes[ tagName ].handles( prop )
        );
        if ( !fieldTag ) {
          throw new Error( `Could not find field to handle prop: ${JSON.stringify(prop)}` );
        }
        const field = document.createElement( fieldTag ) as SchemaField;
        field.setAttribute( "name", propName );
        field.schema = prop;
        this._root.appendChild( field );
      }
    }
    // XXX: Handle array types
    this._schema = newSchema;
  }

  set value(newValue: any) {
    for ( let propName in newValue ) {
      let field = this.querySelector( `[name=${propName}]` ) as SchemaField;
      field.value = newValue[ propName ];
    }
  }

  get value(): any {
    let val = {} as any;
    for ( const el of this._root.children ) {
      const field = el as SchemaField;
      val[ field.name ] = field.value;
    }
    return val;
  }

  connectedCallback() {
    this.appendChild( this._root );
  }

}

import TextInput from './schemafield/textinput';
SchemaForm.addFieldType( TextInput );

