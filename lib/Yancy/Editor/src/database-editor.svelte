<script lang="ts">
  import { onMount } from "svelte";
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  import { marked } from "marked";
  let { schema }: { schema: string } = $props();
  let jsonSchema: JSONSchema = $state({});
  let columns: Array<{ field: string; title: string }> = $state([]);
  let rows: Array<any> = $state([]);

  $effect(async () => {
    const schemaUrl = "./api";
    const dataUrl = schemaUrl + "/" + schema;

    // First, get the schema
    let res = await fetch(schemaUrl);
    const apiSchema = await res.json();
    if (!apiSchema[schema]) {
      jsonSchema = { title: "Schema not found" };
      return;
    }

    jsonSchema = apiSchema[schema];
    if (jsonSchema.properties) {
      columns = Object.keys(jsonSchema.properties).map((c) => ({
        field: c,
        title: c,
      }));
    }

    // Then, get the first page
    res = await fetch(dataUrl);
    const firstPage = await res.json();
    rows = firstPage.items;
  });
</script>

<div>
  <h2 id="table-name">{jsonSchema.title ? jsonSchema.title : schema}</h2>
  {#if jsonSchema.description}
    <div>{marked(jsonSchema.description)}</div>
  {/if}

  {#if rows.length <= 0}
    <p>No items found.</p>
  {:else}
    <table aria-labelledby="table-name">
      <thead>
        <tr>
          {#each columns as col}
            <th> {col.title} </th>
          {/each}
        </tr>
      </thead>
      <tbody>
        {#each rows as row}
          <tr>
            {#each columns as col}
              <td> {row[col.field]} </td>
            {/each}
          </tr>
        {/each}
      </tbody>
    </table>
    <nav aria-label="List page navigation"></nav>
  {/if}
</div>

<style>
</style>
