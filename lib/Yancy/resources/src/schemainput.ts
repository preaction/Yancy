import { SchemaProperty } from './schema'

export abstract class SchemaInput extends HTMLElement {
  name: string;
  abstract schema: SchemaProperty;
  abstract value: any;
  static handles( input: SchemaProperty ): boolean {
    return false;
  }
}

export type SchemaInputClass = {
  new( ...args: any[] ): SchemaInput;
  handles(input: SchemaProperty): boolean;
  register(): string;
}

