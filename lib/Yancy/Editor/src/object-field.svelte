<script lang="ts">
  import type { YancySchema } from "./types.d.ts";
  import SchemaField from "./schema-field.svelte";

  type Column = {
    field: string;
    title: string;
    type: YancySchema["type"];
    order: number;
    schema: YancySchema;
  };

  let {
    schema,
    value = {},
    storage,
    errors = {},
    onchange = () => ({}),
  }: {
    schema: YancySchema;
    value?: any;
    errors?: any;
    storage: string;
    onchange?: (newValue: any) => void;
  } = $props();
  let newValue = $derived(JSON.parse(JSON.stringify(value)));
  let columns = $derived.by(() => {
    const columns: Column[] = [];
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

  // This returns true for types that do not map simply to a single input.
  // These types render a region, not a simple label.
  function isComplexType(col: Column) {
    const complexTypes = ["array", "object"];
    // This could be a serialized complex type.
    if (col.schema.contentMediaType === "application/json") {
      return complexTypes.includes(col.schema.schema.type);
    }
    return complexTypes.includes(col.type);
  }

  function updateValue(fieldName: string, value: any) {
    newValue[fieldName] = value;
    onchange(newValue);
  }
</script>

<div>
  {#each columns as col}
    {#if isComplexType(col)}
      <fieldset>
        <legend>{col.title || col.field}</legend>
        <SchemaField
          {storage}
          id={"field-" + col.field}
          name={col.field}
          schema={col.schema}
          value={newValue[col.field]}
          error={errors[col.field]}
          onchange={(changeValue) => updateValue(col.field, changeValue)}
        />
      </fieldset>
    {:else}
      <div>
        <label for="field-{col.field}">{col.title || col.field}</label>
      </div>
      <SchemaField
        {storage}
        id={"field-" + col.field}
        name={col.field}
        schema={col.schema}
        value={newValue[col.field]}
        error={errors[col.field]}
        onchange={(changeValue) => updateValue(col.field, changeValue)}
      />
    {/if}
  {/each}
</div>
