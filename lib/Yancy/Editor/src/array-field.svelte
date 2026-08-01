<script lang="ts">
  import type { YancySchema } from "./types.d.ts";
  import SchemaField from "./schema-field.svelte";

  let {
    name,
    schema,
    value = [],
    storage,
    errors = {},
    onchange = () => ({}),
  }: {
    name: string;
    schema: YancySchema;
    value?: any[];
    errors?: any;
    storage: string;
    onchange?: (newValue: any[]) => void;
  } = $props();
  let newValue = $derived(JSON.parse(JSON.stringify(value)));

  function updateValue(index: number, value: any) {
    newValue[index] = value;
    onchange(newValue);
  }
</script>

<div>
  <ol>
    {#each newValue, index}
      <li>
        <label for={"field-" + name + "-" + index}>{index}</label>
        {#if schema.type === "object"}
          <!-- show a button for a dialog -->
        {:else}
          <SchemaField
            {storage}
            id={"field-" + name + "-" + index}
            name={name + "-" + index}
            schema={schema.items}
            value={newValue[index]}
            error={errors[index]}
            onchange={(changeValue) => updateValue(index, changeValue)}
          />
        {/if}}
      </li>
    {/each}
  </ol>
</div>
