<script lang="ts">
  import type { HTMLTableAttributes } from "svelte/elements";
  import type { YancyListQuery, YancySchema } from "./types";
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
    query,
    ...attrs
  }: {
    schema: YancySchema;
    src: string;
    controls?: Snippet<[any]>;
    query?: YancyListQuery;
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
    page: number = 1;
    limit: number = 10;
    totalPages: number = 2;

    constructor(src: string, query: YancyListQuery) {
      this.src = src;
      let page = 1;
      if (query.$page) {
        page =
          typeof query.$page === "string" ? parseInt(query.$page) : query.$page;
      }
      this.page = page;
      let limit = 10;
      if (query.$limit) {
        limit =
          typeof query.$limit === "string"
            ? parseInt(query.$limit)
            : query.$limit;
      }
      this.limit = limit;
    }
    async fetch() {
      this.isLoading = true;
      try {
        let src = new URL(this.src, window.location.origin);
        if (this.page > 1) {
          src.searchParams.set("$page", this.page.toString());
        }
        src.searchParams.set("$limit", this.limit.toString());

        const response = await fetch(src.toString());
        const list = await response.json();
        this.items = list.items;
        this.totalPages = Math.ceil(
          list.total / (this.limit ?? list.items.length),
        );
        this.error = undefined;
      } catch (err) {
        this.error = err;
        this.items = [];
        this.totalPages = 0;
      }
      this.isLoading = false;
    }
    urlForPrevious(): string {
      return this.urlFor({ page: this.page - 1 });
    }

    urlForNext(): string {
      return this.urlFor({ page: this.page + 1 });
    }

    urlFor({ page }: { page: number }): string {
      return `?$page=${page}&$limit=${this.limit}`;
    }
  }

  function fetchDataPage(src: string, query: YancyListQuery = {}): DataPage {
    const resp = new DataPage(src, query);
    resp.fetch();
    return resp;
  }

  let data = $derived(fetchDataPage(src, query));

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
    <nav aria-label="Pagination">
      <a
        role="button"
        href={data.urlForPrevious()}
        onclick={(e) => {
          if (data.page === 1) {
            e.preventDefault();
            e.stopImmediatePropagation();
          }
        }}
        aria-disabled={data.page === 1}>Previous</a
      >
      <a
        role="button"
        href={data.urlForNext()}
        onclick={(e) => {
          if (data.page >= data.totalPages) {
            e.preventDefault();
            e.stopImmediatePropagation();
          }
        }}
        aria-disabled={data.page >= data.totalPages}>Next</a
      >
    </nav>
  {/if}
</div>
