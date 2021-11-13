import { SchemaProperty } from '../schema'
import { SchemaField, SchemaFieldClass } from '../schemafield';

export default class TextInput extends SchemaField {
  input: HTMLInputElement;

  constructor() {
    super();
    this.input = document.createElement( 'input' );
  }

  get value(): any {
    return this.input.value;
  }
  set value( newValue: any ) {
    this.input.value = newValue;
  }

  set schema( newSchema: SchemaProperty ) {
    console.log( "Setting schema for textinput", newSchema );
    let fieldType = 'text';
    let inputMode = 'text';
    let pattern = newSchema.pattern;

    if ( newSchema.type === 'string' ) {
      if ( newSchema.format === 'email' ) {
        fieldType = 'email';
        inputMode = 'email';
      }
      else if ( newSchema.format === 'url' ) {
        fieldType = 'url';
        inputMode = 'url';
      }
      else if ( newSchema.format === 'tel' ) {
        fieldType = 'tel';
        inputMode = 'tel';
      }
    }
    else if ( newSchema.type === 'integer' || newSchema.type === 'number' ) {
      fieldType = 'number';
      inputMode = 'decimal';
      if ( newSchema.type  === 'integer' ) {
        // Use pattern to show numeric input on iOS
        // https://css-tricks.com/finger-friendly-numerical-inputs-with-inputmode/
        pattern = pattern || '[0-9]*';
        inputMode = 'numeric';
      }
    }

    this.input.setAttribute( 'type', fieldType );
    this.input.setAttribute( 'inputmode', inputMode );
    if ( pattern ) {
      this.input.setAttribute( 'pattern', pattern );
    }
    if ( newSchema.minLength ) {
      this.input.setAttribute( 'minlength', newSchema.minLength.toString() );
    }
    if ( newSchema.maxLength ) {
      this.input.setAttribute( 'maxlength', newSchema.maxLength.toString() );
    }
    if ( newSchema.minimum ) {
      this.input.setAttribute( 'min', newSchema.minimum.toString() );
    }
    if ( newSchema.maximum ) {
      this.input.setAttribute( 'max', newSchema.maximum.toString() );
    }
  }

  connectedCallback() {
    this.appendChild( this.input );
  }

  static handles( field: SchemaProperty ): boolean {
    return true;
  }

  static register():string {
    const tagName = 'schema-text-input';
    window.customElements.define( tagName, TextInput );
    return tagName;
  }
}
