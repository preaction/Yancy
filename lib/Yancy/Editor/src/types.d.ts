import type { JSONSchema7, JSONSchema7Object } from "json-schema";

declare global {
  interface Window {
    Yancy: { base: string };
  }
}

type YancyExtra = {
  "x-id-field"?: string | Array<string>;
  "x-list-columns"?: Array<string>;
  "x-view-url"?: string;
  "x-view-item-url"?: string;
  "x-html-field"?: string;
  "x-hidden"?: boolean;
  "x-foreign-key"?: string;
  "x-display-field"?: string;
  "x-order"?: number;
  "x-mime-type"?: string | Array<string>;
  properties?: { [key: string]: YancySchema };
  items?: YancySchema;
};
export type YancySchema = Omit<JSONSchema7, "properties", "items"> & YancyExtra;

export type YancyListQuery =
  | {
      $page?: number;
      $limit?: number;
      $order_by?: string;
    }
  | { [key: string]: string };
