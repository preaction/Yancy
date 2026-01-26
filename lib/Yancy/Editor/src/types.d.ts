export type JSONType = {};

export type JSONSchemaProperties = {
  [key: string]: JSONType;
};

export type JSONSchema = {
  title: string;
  description: string;
  properties: JSONSchemaProperties;
  [key: string]: any;
};
