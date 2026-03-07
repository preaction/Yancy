<script lang="ts">
  import type { YancySchema } from "./types.d.ts";
  import SchemaField from "./schema-field.svelte";

  let {
    schema,
    value = {},
    storage,
    onchange = () => ({}),
  }: {
    schema: YancySchema;
    value?: any;
    storage: string;
    onchange?: (newValue: any) => void;
  } = $props();
  let newValue = $derived(JSON.parse(JSON.stringify(value)));
  let columns = $derived.by(() => {
    const columns = [];
    // XXX: This is duplicated, so create a wrapper object instead
    if (schema.properties) {
      for (const [field, fieldSchema] of Object.entries(schema.properties)) {
        if (typeof fieldSchema !== "object") {
          continue;
        }
        if (!fieldSchema.type || fieldSchema["x-hidden"]) {
          continue;
        }
        const type: string = Array.isArray(fieldSchema.type)
          ? fieldSchema.type[0]
          : fieldSchema.type;
        columns.push({
          field,
          title: field,
          type,
          order: fieldSchema["x-order"] || Number.MAX_SAFE_INTEGER,
          schema: fieldSchema,
        });
      }
    }
    columns.sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
    return columns;
  });

  function updateValue(fieldName: string, value: any) {
    newValue[fieldName] = value;
    onchange(newValue);
  }
</script>

<div>
  {#each columns as col}
    <div>
      <label for="field-{col.field}">{col.title || col.field}</label>
    </div>
    <SchemaField
      {storage}
      id={"field-" + col.field}
      name={col.field}
      schema={col.schema}
      value={newValue[col.field]}
      onchange={(changeValue) => updateValue(col.field, changeValue)}
    />
  {/each}
</div>
