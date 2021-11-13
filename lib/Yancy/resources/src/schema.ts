
export type SchemaProperty = {
  type: string;
  format?: string;
  enum?: Array<string>;
  pattern?: string;
  minLength?: Number;
  maxLength?: Number;
  minimum?: Number;
  maximum?: Number;
  readOnly?: boolean;
  writeOnly?: boolean;
}

// XXX: Create Schema type

