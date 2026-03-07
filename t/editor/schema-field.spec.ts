import { render, screen } from "@testing-library/svelte";
import { expect, test, describe, afterAll, afterEach, beforeAll } from "vitest";
import userEvent from "@testing-library/user-event";
import type { YancySchema } from "../../lib/Yancy/Editor/src/types.d.ts";

import SchemaField from "../../lib/Yancy/Editor/src/schema-field.svelte";
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

describe("SchemaField", () => {
  describe("shows correct input for data column and binds value", () => {
    type TestCase = {
      title: string;
      schema: YancySchema;
      value: any;
      check(testCase: TestCase): Promise<void>;
      update?(testCase: TestCase, user: UserEvent): Promise<void>;
      submit?(testCase: TestCase, value: any): Promise<void>;
    };
    const testCases: TestCase[] = [
      {
        title: "shows correct input for plain string",
        schema: { type: "string" },
        value: "stringValue",
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLTextAreaElement);
          expect(field).toHaveValue(testCase.value);
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("combobox") as HTMLSelectElement;
          expect(field).toBeInstanceOf(HTMLSelectElement);
          expect(field).toBeVisible();
          expect(field).toHaveValue(testCase.value);
          expect(field.options[0]).toHaveTextContent("enumOne");
          expect(field.options[1]).toHaveTextContent("enumTwo");
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("combobox") as HTMLSelectElement;
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
        check: async (_testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("checkbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "checkbox");
          expect(field).toBeChecked();
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("checkbox");
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
        check: async (_testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("checkbox");
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
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "text");
          expect(field).toHaveValue(testCase.value.toString());
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "text");
          expect(field).toHaveValue(testCase.value.toString());
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByTestId("fieldName");
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
          const field = screen.getByTestId("fieldName");
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
          const field = screen.getByRole("textbox");
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
          const field = screen.getByRole("textbox");
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
          const field = screen.getByRole("textbox");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByTestId("fieldName");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveAttribute("type", "file");
          expect(field.parentElement).toHaveTextContent(testCase.value);
        },
        update: async (_testCase: TestCase, user: UserEvent): Promise<void> => {
          const field = screen.getByTestId("fieldName");
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
        check: async (testCase: TestCase): Promise<void> => {
          const field = screen.getByRole("textbox");
          expect(field).toBeVisible();
          expect(field).toBeInstanceOf(HTMLInputElement);
          expect(field).toHaveValue(testCase.value);
          expect(field).toBeDisabled();
        },
      },
    ];

    for (const testCase of testCases) {
      test(testCase.title, async ({}) => {
        const newValue = JSON.parse(JSON.stringify(testCase.value));

        const user = userEvent.setup();
        let gotValue: any;
        render(SchemaField, {
          name: "fieldName",
          id: "fieldName",
          testid: "fieldName",
          schema: testCase.schema,
          value: newValue,
          storage: "./storage",
          onchange: (v) => (gotValue = v),
        });
        await testCase.check(testCase);
        if (testCase.update) {
          await testCase.update(testCase, user);

          // Value is not altered until submit
          expect(newValue).toBe(testCase.value);

          if (testCase.submit) {
            expect(gotValue).toBeDefined();
            await testCase.submit(testCase, gotValue);
          }
        }
      });

      test(testCase.title + " -- optional", async ({}) => {
        const schema = JSON.parse(JSON.stringify(testCase.schema));
        if (typeof schema.type === "string") {
          schema.type = [schema.type, "null"];
        }

        const newValue = JSON.parse(JSON.stringify(testCase.value));

        const user = userEvent.setup();
        let gotValue: any;
        render(SchemaField, {
          name: "fieldName",
          id: "fieldName",
          testid: "fieldName",
          schema,
          value: newValue,
          storage: "./storage",
          onchange: (v) => (gotValue = v),
        });
        await testCase.check(testCase);
        if (testCase.update) {
          await testCase.update(testCase, user);

          // Value is not altered until submit
          expect(newValue).toBe(testCase.value);

          if (testCase.submit) {
            expect(gotValue).toBeDefined();
            await testCase.submit(testCase, gotValue);
          }
        }
      });
    }
  });
});
