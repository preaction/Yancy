
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
  "x-order"?: Number;
}

export type SchemaObject = {
  type?: string,
  title?: string,
  description?: string,
  required?: string[],
  properties: { [index:string]: SchemaProperty },
}

export type Schema = {
  [index:string]: SchemaObject,
}

