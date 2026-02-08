<script lang="ts">
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  import type { HTMLFormAttributes } from "svelte/elements";
  import MarkdownField from "./markdown-field.svelte";
  import FileField from "./file-field.svelte";

  function isNumberType(schema: JSONSchema): boolean {
    const typeName =
      typeof schema.type == "string"
        ? schema.type
        : Array.isArray(schema.type)
          ? schema.type[0]
          : "";
    return ["number", "integer"].includes(typeName);
  }
  function isFalsey(value: any): boolean {
    if (typeof value == "boolean") {
      return !value;
    } else if (typeof value == "number") {
      return !value;
    } else if (typeof value == "string") {
      return value == "false" || value == "0";
    }
    return false;
  }

  let {
    schema,
    value = {},
    onsubmit = () => {},
    oncancel = () => {},
    ...attrs
  }: {
    schema: JSONSchema;
    value: any;
    onsubmit?: (value: any) => void;
    oncancel?: () => void;
    attrs?: HTMLFormAttributes;
  } = $props();
  let newValue = $derived(value);
  let columns = $derived.by(() => {
    const columns = [];
    // XXX: This is duplicated, so create a wrapper object instead
    if (schema.properties) {
      for (const field of Object.keys(schema.properties)) {
        const fieldSchema = schema.properties[field];
        if (typeof fieldSchema !== "object") {
          continue;
        }
        if (!fieldSchema.type || fieldSchema["x-hidden"]) {
          continue;
        }
        const type: string = Array.isArray(fieldSchema.type)
          ? fieldSchema.type[0]
          : fieldSchema.type;
        columns.push({ field, title: field, type, schema: fieldSchema });
      }
    }
    return columns;
  });

  function updateField(e: Event, fieldName: string) {
    newValue[fieldName] = (e.target as HTMLInputElement).value;
  }
  function updateNumberField(e: Event, fieldName: string) {
    newValue[fieldName] = parseFloat((e.target as HTMLInputElement).value);
  }

  function saveForm(_e: SubmitEvent) {
    onsubmit(newValue);
  }
</script>

<form {...attrs} onsubmit={saveForm}>
  {#each columns as col}
    <div>
      <label for="field-{col.field}">{col.title || col.field}</label>
    </div>
    <div>
      {#if col.type == "string" && col.schema.format == "textarea"}
        <textarea
          name={col.field}
          id="field-{col.field}"
          disabled={col.schema.readOnly}
          value={value[col.field]}
          oninput={(e) => updateField(e, col.field)}
        ></textarea>
      {:else if col.type == "boolean"}
        <input
          type="checkbox"
          name={col.field}
          id="field-{col.field}"
          checked={!isFalsey(value[col.field])}
          disabled={col.schema.readOnly}
          onchange={(e: Event) => {
            value[col.field] = (e.target as HTMLInputElement)?.checked;
          }}
        />
      {:else if col.schema.enum}
        <select
          name={col.field}
          value={value[col.field]}
          id="field-{col.field}"
          disabled={col.schema.readOnly}
          onchange={(e) => {
            value[col.field] = (e.target as HTMLSelectElement).value;
          }}
        >
          {#each col.schema.enum as enumValue}
            <option>{enumValue}</option>
          {/each}
        </select>
      {:else if isNumberType(col.schema)}
        <input
          type="number"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          disabled={col.schema.readOnly}
          oninput={(e) => updateNumberField(e, col.field)}
        />
      {:else if col.type == "string" && col.schema.format == "markdown"}
        <MarkdownField
          id="field-{col.field}"
          value={value[col.field]}
          oninput={(newValue: string) => {
            value[col.field] = newValue;
          }}
        ></MarkdownField>
      {:else if col.type == "string" && col.schema.format == "date"}
        <input
          type="date"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          onchange={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
        />
      {:else if col.type == "string" && col.schema.format == "date-time"}
        <input
          type="datetime-local"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          onchange={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
        />
      {:else if col.type == "string" && col.schema.format == "email"}
        <input
          type="email"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          oninput={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
        />
      {:else if col.type == "string" && col.schema.format == "url"}
        <input
          type="url"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          oninput={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
        />
      {:else if col.type == "string" && col.schema.format == "tel"}
        <input
          type="tel"
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          onchange={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
          oninput={(e) => updateField(e, col.field)}
        />
      {:else if col.type == "string" && col.schema.format == "filepath"}
        <FileField
          id="field-{col.field}"
          name={col.field}
          value={value[col.field]}
          disabled={col.schema.readOnly}
          onchange={(newValue) => (value[col.field] = newValue)}
        />
      {:else if col.type == "string"}
        <input
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          oninput={(e) => updateField(e, col.field)}
          disabled={col.schema.readOnly}
        />
      {:else}
        Unknown type: {col.type}
      {/if}
    </div>
  {/each}
  <button>Save</button>
  <button
    onclick={(e) => {
      e.preventDefault();
      oncancel();
    }}>Cancel</button
  >
</form>
