import { render, screen } from "@testing-library/svelte";
import { expect, test, describe, afterAll, afterEach, beforeAll } from "vitest";
import userEvent from "@testing-library/user-event";
import type { JSONSchema7 as JSONSchema } from "json-schema";

import EditForm from "../../lib/Yancy/Editor/src/edit-form.svelte";
import type { UserEvent } from "@testing-library/user-event/dist/cjs/setup/setup.js";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

const handlers = [
  http.put("./storage/:id", () => {
    return HttpResponse.arrayBuffer(new ArrayBuffer(), { status: 201 });
  }),
];
const server = setupServer(...handlers);
beforeAll(() => {
  server.listen({ onUnhandledRequest: "error" });
});
afterEach(() => {
  server.resetHandlers();
});
afterAll(() => {
  server.close();
});

describe("EditForm", () => {
  describe("shows correct input for data column and binds value", () => {
    type TestCase = {
      title: string;
      schema: JSONSchema;
      value: any;
      check(testCase: TestCase, fieldName: string): Promise<void>;
      update?(
        testCase: TestCase,
        user: UserEvent,
        fieldName: string,
      ): Promise<void>;
      submit?(testCase: TestCase, value: any): Promise<void>;
    };
    const testCases: TestCase[] = [
      {
        title: "shows correct input for plain string",
        schema: { type: "string" },
        value: "stringValue",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.clear(field);
          await user.type(field, "newValue");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe("newValue");
        },
      },

      {
        title: "shows correct input for textarea string",
        schema: { type: "string", format: "textarea" },
        value: "stringValue",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.clear(field);
          await user.type(field, "newValue");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe("newValue");
        },
      },

      {
        title: "shows correct input for markdown string",
        schema: { type: "string", format: "markdown" },
        value: "stringValue",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.clear(field);
          await user.type(field, "newValue");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe("newValue");
        },
      },

      {
        title: "shows correct input for string enum",
        schema: { type: "string", enum: ["enumOne", "enumTwo"] },
        value: "enumTwo",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName) as HTMLSelectElement;
          expect(field).toBeInstanceOf(HTMLSelectElement);
          expect(field).toBeVisible();
          expect(field).toHaveValue(testCase.value);
          expect(field.options[0]).toHaveTextContent("enumOne");
          expect(field.options[1]).toHaveTextContent("enumTwo");
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.selectOptions(field, "enumOne");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe("enumOne");
        },
      },

      {
        title: "shows correct input for boolean",
        schema: { type: "boolean" },
        value: "true",
        check: async (
          _testCase: TestCase,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "checkbox");
          expect(field).toBeChecked();
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.click(field);
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe(false);
        },
      },

      {
        title: "shows correct input for boolean (false)",
        schema: { type: "boolean" },
        value: "false",
        check: async (
          _testCase: TestCase,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
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
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "number");
          expect(field).toHaveValue(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.clear(field);
          await user.type(field, "812");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe(812);
        },
      },

      {
        title: "shows correct input for number",
        schema: { type: "number" },
        value: 9.23,
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "number");
          expect(field).toHaveValue(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          await user.clear(field);
          await user.type(field, "8.12");
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe(8.12);
        },
      },

      {
        title: "shows correct input for date",
        schema: { type: "string", format: "date" },
        value: "2025-01-01",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
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
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
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
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
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
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
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
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "tel");
          expect(field).toHaveValue(testCase.value);
        },
      },

      {
        title: "shows correct input for file",
        schema: { type: "string", format: "filepath" },
        value: "ok.webp",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "file");
          expect(field.parentElement).toHaveTextContent(testCase.value);
        },
        update: async (
          _testCase: TestCase,
          user: UserEvent,
          fieldName: string,
        ): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          const file = new File(["hello"], "hello.png", { type: "image/png" });
          await user.upload(field, file);
        },
        submit: async (_testCase: TestCase, value: any): Promise<void> => {
          expect(value).toBe("hello.png");
          // XXX: Remove uploaded file
        },
      },

      {
        title: "shows readOnly value",
        // TODO: Each field has its own readonly-style
        schema: { type: "string", readOnly: true },
        value: "readOnly",
        check: async (testCase: TestCase, fieldName: string): Promise<void> => {
          const field = screen.getByLabelText(fieldName);
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
          expect(field).toBeDisabled();
        },
      },

      {
        title: "does not show x-hidden field",
        schema: { type: "string", "x-hidden": true },
        value: "readOnly",
        check: async (
          _testCase: TestCase,
          fieldName: string,
        ): Promise<void> => {
          expect(screen.queryByLabelText(fieldName)).toBeNull();
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

        const user = userEvent.setup();
        render(EditForm, { schema, value });
        await testCase.check(testCase, "fieldName");
        if (testCase.update) {
          await testCase.update(testCase, user, "fieldName");
          if (testCase.submit) {
            await testCase.submit(testCase, value.fieldName);
          }
        }
      });

      test(testCase.title + " -- optional", async ({}) => {
        const schema: JSONSchema = {
          type: "object",
          properties: {
            fieldName: testCase.schema,
          },
        };
        // Make the field optional
        if (
          typeof schema.properties?.fieldName === "object" &&
          typeof schema.properties.fieldName.type === "string"
        ) {
          schema.properties.fieldName.type = [
            schema.properties.fieldName.type,
            "null",
          ];
        }

        const value = {
          fieldName: testCase.value,
        };

        const user = userEvent.setup();
        render(EditForm, { schema, value });
        await testCase.check(testCase, "fieldName");
        if (testCase.update) {
          await testCase.update(testCase, user, "fieldName");
          if (testCase.submit) {
            await testCase.submit(testCase, value.fieldName);
          }
        }
      });
    }
  });
});
