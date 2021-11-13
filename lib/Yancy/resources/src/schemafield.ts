import { SchemaProperty } from './schema'

export abstract class SchemaField extends HTMLElement {
  name: string;
  abstract schema: SchemaProperty;
  abstract value: any;
  static handles( field: SchemaProperty ): boolean {
    return false;
  }
}

export type SchemaFieldClass = {
  new( ...args: any[] ): SchemaField;
  handles(field: SchemaProperty): boolean;
  register(): string;
}

