import type { JSONSchema7, JSONSchema7Object } from "json-schema";
type YancyExtra = {
  "x-list-columns"?: Array<string>;
  "x-view-url"?: string;
  "x-view-item-url"?: string;
  "x-html-field"?: string;
  "x-hidden"?: boolean;
  "x-foreign-key"?: string;
  "x-display-field"?: string;
};
export type YancySchema = JSONSchema7 & YancyExtra;
