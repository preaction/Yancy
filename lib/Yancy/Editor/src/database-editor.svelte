<script lang="ts">
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  type YancySchema = JSONSchema & {
    "x-id-field": string | string[];
  };
  type ColumnDef = {
    field: string;
    title: string;
    schema: JSONSchema;
  };
  import { marked } from "marked";
  import EditForm from "./edit-form.svelte";

  const apiUrl = "./api";
  let { schema }: { schema: string } = $props();

  class DataSchema {
    schema: YancySchema | undefined = $state();
    error = $state();
    isLoading = $state(false);

    get idFields() {
      if (!this.schema) {
        return [];
      }
      return Array.isArray(this.schema["x-id-field"])
        ? this.schema["x-id-field"]
        : [this.schema["x-id-field"]];
    }
  }

  function fetchSchema(schema: string): DataSchema {
    const resp = new DataSchema();

    async function fetchSchema() {
      resp.isLoading = true;
      try {
        const response = await fetch(apiUrl);
        const allSchema = await response.json();
        if (allSchema[schema]) {
          resp.schema = allSchema[schema];
          resp.error = undefined;
        } else {
          resp.error = new Error("Schema not found");
        }
      } catch (err) {
        resp.error = err;
        resp.schema = undefined;
      }
      resp.isLoading = false;
    }

    fetchSchema();
    return resp;
  }

  let dataSchema = $derived(fetchSchema(schema));
  let columns: Array<ColumnDef> = $derived(buildColumns(dataSchema.schema));

  class DataPage {
    schema: string;
    items = $state([]);
    error = $state();
    isLoading = $state(false);
    constructor(schema: string) {
      this.schema = schema;
    }
    async fetch() {
      this.isLoading = true;
      try {
        const response = await fetch(apiUrl + "/" + this.schema);
        this.items = (await response.json()).items;
        this.error = undefined;
      } catch (err) {
        this.error = err;
        this.items = [];
      }
      this.isLoading = false;
    }
  }

  function fetchDataPage(schema: string): DataPage {
    const resp = new DataPage(schema);
    resp.fetch();
    return resp;
  }

  let data = $derived(fetchDataPage(schema));

  let editRow: any = $state();

  function buildColumns(jsonSchema: YancySchema | undefined): ColumnDef[] {
    const columns = [];
    if (jsonSchema?.properties) {
      for (const field of Object.keys(jsonSchema.properties)) {
        const schema = jsonSchema.properties[field];
        if (typeof schema !== "object") {
          continue;
        }
        columns.push({ field, title: field, schema });
      }
    }
    return columns;
  }

  function addRow() {
    openFormForRow({});
  }

  function openFormForRow(row: any) {
    const dialog = document.getElementById("edit-dialog") as
      | HTMLDialogElement
      | undefined;
    if (dialog) {
      dialog.showModal();
    }
    editRow = row;
  }

  async function saveRow(row: any) {
    let url = apiUrl + "/" + schema + "/";
    if (dataSchema.idFields.every((k) => row[k])) {
      url += dataSchema.idFields.map((k) => row[k]).join("/");
    }

    // XXX: What if some ID fields are not read-only? We would need to remember
    // the old value and then set the new value.

    // Remove all read-only fields, since we can't set them
    for (const [key, schema] of Object.entries(
      dataSchema.schema?.properties || {},
    )) {
      if (typeof schema === "object" && schema.readOnly) {
        delete row[key];
      }
    }

    const res = await fetch(url, {
      method: "POST",
      body: JSON.stringify(row),
    });
    if (!res.ok) {
      // XXX: Show error
      return;
    }
    // Refresh page
    data.fetch();

    closeDialog();
  }

  function closeDialog() {
    editRow = undefined;
    const dialog = document.getElementById("edit-dialog") as
      | HTMLDialogElement
      | undefined;
    if (dialog) {
      dialog.close();
    }
  }

  /**
   * Cancel editing whatever is in the dialog. Show a pop-up if whatever has
   * been edited and user would lose changes.
   */
  function cancelDialog() {
    // XXX: Warn user before doing this
    closeDialog();
  }
</script>

{#if dataSchema.isLoading}
  Fetching...
{:else}
  <div role="region" aria-label="Database Editor">
    {#if !dataSchema.schema}
      Schema not found
    {:else}
      <h2 id="table-name">
        {dataSchema.schema.title ? dataSchema.schema.title : schema}
      </h2>
      {#if dataSchema.schema.description}
        <div>{marked(dataSchema.schema.description)}</div>
      {/if}

      <button onclick={() => addRow()}>Add</button>

      {#if data.isLoading}
        Fetching...
      {:else if !data.items?.length}
        <p>No items found.</p>
      {:else}
        <table aria-labelledby="table-name">
          <thead>
            <tr>
              <th></th>
              {#each columns as col}
                <th> {col.title} </th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each data.items as row}
              <tr>
                <td
                  ><button onclick={() => openFormForRow(row)}>Edit</button></td
                >
                {#each columns as col}
                  <td> {row[col.field]} </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
        <nav aria-label="List page navigation"></nav>
      {/if}

      <dialog open={editRow} id="edit-dialog" oncancel={() => cancelDialog()}>
        <header>
          <h3 id="edit-item-heading">Edit Item</h3>
        </header>
        <EditForm
          aria-labelledby="edit-item-heading"
          id="edit-form"
          method="dialog"
          schema={dataSchema.schema}
          value={editRow}
          onsubmit={saveRow}
          oncancel={cancelDialog}
        />
      </dialog>
    {/if}
  </div>
{/if}

<style>
</style>
