<script lang="ts">
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  import type { HTMLFormAttributes } from "svelte/elements";

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
      {#if col.schema.readOnly}
        {value[col.field]}
      {:else if col.schema.type == "string" && col.schema.format == "textarea"}
        <textarea name={col.field} id="field-{col.field}"
          >{value[col.field]}</textarea
        >
      {:else if col.schema.type == "string"}
        <input
          name={col.field}
          id="field-{col.field}"
          value={value[col.field]}
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
