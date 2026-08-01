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

  function addItem(e: Event) {
    e.preventDefault();
    // Need to replace newValue wholly so that the original derived value
    // doesn't take precedence. This prevents the existing value prop from
    // being modified, allows the existing value prop to change, but lets us
    // wait until we have a proper value in the new item before trigging the
    // onchange event.
    newValue = [...newValue, null];
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
  <button type="button" onclick={addItem}>Add</button>
</div>
