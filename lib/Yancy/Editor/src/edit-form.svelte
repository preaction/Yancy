<script lang="ts">
  import type {
    JSONSchema7 as JSONSchema,
    JSONSchema7TypeName,
  } from "json-schema";
  import type { HTMLFormAttributes } from "svelte/elements";

  function isNumberType(schema: JSONSchema): boolean {
    const typeName =
      typeof schema.type == "string"
        ? schema.type
        : Array.isArray(schema.type)
          ? schema.type[0]
          : "";
    return ["number", "integer"].includes(typeName);
  }

  let {
    schema,
    value,
    onsubmit,
    oncancel,
    ...attrs
  }: {
    schema: JSONSchema;
    value: any;
    onsubmit: (value: any) => void;
    oncancel: () => void;
    attrs: HTMLFormAttributes;
  } = $props();
  let columns = $derived.by(() => {
    const columns = [];
    // XXX: This is duplicated, so create a wrapper object instead
    if (schema.properties) {
      for (const field of Object.keys(schema.properties)) {
        const fieldSchema = schema.properties[field];
        if (typeof fieldSchema !== "object") {
          continue;
        }
        columns.push({ field, title: field, schema: fieldSchema });
      }
    }
    return columns;
  });

  function saveForm(e: SubmitEvent) {
    // TODO: Go through the form and get the values out of the fields
    const newValue = { ...value };
    onsubmit(newValue);
  }
</script>

<form {...attrs} onsubmit={saveForm}>
  {#each columns as col}
    <div>
      <label for="field-{col.field}">{col.title || col.field}</label>
    </div>
    <div>
      {#if col.schema.type == "string" && col.schema.format == "textarea"}
        <textarea
          name={col.field}
          id="field-{col.field}"
          disabled={col.schema.readOnly}>{value[col.field]}</textarea
        >
      {:else if col.schema.enum}
        <select
          name={col.field}
          bind:value={value[col.field]}
          id="field-{col.field}"
          disabled={col.schema.readOnly}
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
        />
      {:else if col.schema.type == "string"}
        <input
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
          disabled={col.schema.readOnly}
        />
      {:else}
        :shrug:
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
