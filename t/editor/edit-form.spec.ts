import { render, screen } from "@testing-library/svelte";
import { expect, test, describe } from "vitest";
import type { JSONSchema7 as JSONSchema } from "json-schema";

import EditForm from "../../lib/Yancy/Editor/src/edit-form.svelte";

describe("EditForm", () => {
  describe.only("shows correct input for data column", () => {
    type TestCase = {
      title: string;
      schema: JSONSchema;
      value: any;
      check(testCase: TestCase): Promise<void>;
    };
    const testCases: TestCase[] = [
      {
        title: "shows correct input for plain string",
        schema: { type: "string" },
        value: "stringValue",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for textarea string",
        schema: { type: "string", format: "textarea" },
        value: "stringValue",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for markdown string",
        schema: { type: "string", format: "markdown" },
        value: "stringValue",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for string enum",
        schema: { type: "string", enum: ["enumOne", "enumTwo"] },
        value: "enumTwo",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName") as HTMLSelectElement;
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLSelectElement);
          expect(field).toHaveValue(testCase.value);
          expect(field.options[0]).toHaveTextContent("enumOne");
          expect(field.options[1]).toHaveTextContent("enumTwo");
        },
      },

      {
        title: "shows correct input for boolean",
        schema: { type: "boolean" },
        value: "true",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "checkbox");
          expect(field).toBeChecked();
        },
      },

      {
        title: "shows correct input for boolean (false)",
        schema: { type: "boolean" },
        value: "false",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "checkbox");
          expect(field).not.toBeChecked();
        },
      },

      {
        title: "shows correct input for integer",
        schema: { type: "integer" },
        value: 945,
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "number");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for number",
        schema: { type: "number" },
        value: 9.23,
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "number");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for date",
        schema: { type: "string", format: "date" },
        value: "2025-01-01",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "date");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for date-time",
        schema: { type: "string", format: "date-time" },
        value: "2025-01-01T01:20:30.000",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "datetime-local");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for email",
        schema: { type: "string", format: "email" },
        value: "example@example.com",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "email");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for url",
        schema: { type: "string", format: "url" },
        value: "https://example.com",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "url");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for tel",
        schema: { type: "string", format: "tel" },
        value: "+13125550199",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "tel");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows readOnly value",
        // TODO: Each field has its own readonly-style
        schema: { type: "string", readOnly: true },
        value: "readOnly",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByLabelText("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
          expect(field).toBeDisabled();
        },
      },
    ];

    for (const testCase of testCases) {
      test(testCase.title, async ({}) => {
        const schema: JSONSchema = {
          type: "object",
          properties: {
            fieldName: testCase.schema,
          },
        };
        const value = {
          fieldName: testCase.value,
        };

        render(EditForm, { schema, value });
        await testCase.check(testCase);
      });
    }
  });
});
