<script lang="ts">
  import { onMount } from "svelte";
  import type { JSONSchema7 as JSONSchema } from "json-schema";
  import { marked } from "marked";
  import EditForm from "./edit-form.svelte";
  let { schema }: { schema: string } = $props();
  let jsonSchema: JSONSchema = $state({});
  let columns: Array<{
    field: string;
    title: string;
    schema: JSONSchema;
  }> = $state([]);
  let rows: Array<any> = $state([]);
  let editRow: any = $state({});

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
      columns = [];
      for (const field of Object.keys(jsonSchema.properties)) {
        const schema = jsonSchema.properties[field];
        if (typeof schema !== "object") {
          continue;
        }
        columns.push({ field, title: field, schema });
      }
    }

    // Then, get the first page
    res = await fetch(dataUrl);
    const firstPage = await res.json();
    rows = firstPage.items;
  });

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

  function saveRow(row: any) {}

  function cancelDialog() {
    const dialog = document.getElementById("edit-dialog") as
      | HTMLDialogElement
      | undefined;
    if (dialog) {
      dialog.close();
    }
  }
</script>

<div role="region" aria-label="Database Editor">
  <h2 id="table-name">{jsonSchema.title ? jsonSchema.title : schema}</h2>
  {#if jsonSchema.description}
    <div>{marked(jsonSchema.description)}</div>
  {/if}

  <button onclick={() => addRow()}>Add</button>

  {#if rows.length <= 0}
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
        {#each rows as row}
          <tr>
            <td><button onclick={() => openFormForRow(row)}>Edit</button></td>
            {#each columns as col}
              <td> {row[col.field]} </td>
            {/each}
          </tr>
        {/each}
      </tbody>
    </table>
    <nav aria-label="List page navigation"></nav>
  {/if}

  <dialog id="edit-dialog" oncancel={() => cancelDialog()}>
    <header>
      <h3 id="edit-item-heading">Edit Item</h3>
    </header>
    <EditForm
      aria-labelledby="edit-item-heading"
      id="edit-form"
      method="dialog"
      schema={jsonSchema}
      value={editRow}
      onsubmit={saveRow}
      oncancel={cancelDialog}
    />
  </dialog>
</div>

<style>
</style>
