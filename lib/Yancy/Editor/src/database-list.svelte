<script lang="ts">
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  import { onMount } from "svelte";
  let { onselect }: { onselect: (schema: string) => void } = $props();
  let databaseSchema: Array<[string, JSONSchema]> = $state([]);

  onMount(async () => {
    const res = await fetch("./api");
    const apiSchema = await res.json();
    databaseSchema = Object.entries(apiSchema);
    databaseSchema = databaseSchema.sort((a, b) => {
      const aTitle = a[1].title?.toLowerCase() || a[0];
      const bTitle = b[1].title?.toLowerCase() || b[0];
      return aTitle > bTitle ? 1 : aTitle < bTitle ? -1 : 0;
    });
  });
</script>

<ul>
  {#each databaseSchema as [schemaName, schema]}
    <li>
      <button onclick={() => onselect(schemaName)}
        >{schema.title || schemaName}</button
      >
    </li>
  {/each}
</ul>

<style>
</style>
