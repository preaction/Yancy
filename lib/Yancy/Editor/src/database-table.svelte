<script lang="ts">
  import type { HTMLTableAttributes } from "svelte/elements";
  import type { YancySchema } from "./types";
  import type { Snippet } from "svelte";

  type ColumnDef = {
    field: string;
    title: string;
    schema: YancySchema;
  };

  let {
    schema,
    src,
    controls,
    ...attrs
  }: {
    schema: YancySchema;
    src: string;
    controls?: Snippet<[any]>;
    attrs?: HTMLTableAttributes;
  } = $props();

  let columns: Array<ColumnDef> = $derived(buildColumns(schema));
  function buildColumns(jsonSchema: YancySchema | undefined): ColumnDef[] {
    const columns = [];
    if (jsonSchema?.properties) {
      const fields =
        jsonSchema["x-list-columns"] || Object.keys(jsonSchema.properties);
      for (const field of fields) {
        const schema = jsonSchema.properties[field];
        if (typeof schema !== "object") {
          continue;
        }
        columns.push({ field, title: field, schema });
      }
    }
    return columns;
  }

  class DataPage {
    src: string;
    items = $state([]);
    error = $state();
    isLoading = $state(false);
    constructor(src: string) {
      this.src = src;
    }
    async fetch() {
      this.isLoading = true;
      try {
        const response = await fetch(this.src);
        this.items = (await response.json()).items;
        this.error = undefined;
      } catch (err) {
        this.error = err;
        this.items = [];
      }
      this.isLoading = false;
    }
  }

  function fetchDataPage(src: string): DataPage {
    const resp = new DataPage(src);
    resp.fetch();
    return resp;
  }

  let data = $derived(fetchDataPage(src));

  export function refresh() {
    data.fetch();
  }
</script>

<div>
  {#if data.isLoading}
    Fetching...
  {:else if !data.items?.length}
    <p>No items found.</p>
  {:else}
    <table {...attrs}>
      <thead>
        <tr>
          {#each columns as col}
            <th scope="col"> {col.title} </th>
          {/each}
          {#if controls}
            <th></th>
          {/if}
        </tr>
      </thead>
      <tbody>
        {#each data.items as row}
          <tr>
            {#each columns as col}
              <td> {row[col.field]} </td>
            {/each}
            {#if controls}
              <td>{@render controls(row)}</td>
            {/if}
          </tr>
        {/each}
      </tbody>
    </table>
    <nav aria-label="List page navigation"></nav>
  {/if}
</div>
