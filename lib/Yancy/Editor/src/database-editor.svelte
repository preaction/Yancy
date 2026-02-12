<script lang="ts">
  import type { YancySchema } from "./types";
  import { marked } from "marked";
  import EditForm from "./edit-form.svelte";
  import DatabaseTable from "./database-table.svelte";
  import { tick } from "svelte";

  let { src, schema }: { src: string; schema: string } = $props();
  const apiUrl = src + "/api";

  class DataSchema {
    schema: YancySchema | undefined = $state();
    error = $state();
    isLoading = $state(false);

    get idFields() {
      if (!this.schema || !this.schema["x-id-field"]) {
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

  let editRow: any = $state();

  function addRow() {
    openFormForRow({});
  }

  async function openFormForRow(row: any) {
    const dialog = document.getElementById("edit-dialog") as
      | HTMLDialogElement
      | undefined;
    if (dialog) {
      dialog.showModal();
    }
    editRow = row;

    // Wait for the form to render
    await tick();

    // Focus the user on the first editable field in the form
    // XXX: Using the autofocus attribute would probably be better here, but
    // that would be in the edit-form and we might have times we don't want to
    // autofocus.
    const form = document.querySelector("#edit-form");
    if (!form) {
      console.warn("Could not find #edit-form to focus");
      return;
    }
    for (const el of form.querySelectorAll(
      "input,textarea,select,[contenteditable]",
    ) as NodeListOf<HTMLElement>) {
      if (!el.hasAttribute("disabled")) {
        el.focus();
        break;
      }
    }
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
    if (dataTable) {
      dataTable.refresh();
    }

    closeDialog();
  }

  let dataTable: DatabaseTable | undefined = $state();
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
  <div class="database-editor" role="region" aria-label="Database Editor">
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

      <DatabaseTable
        bind:this={dataTable}
        aria-labelledby="table-name"
        schema={dataSchema.schema}
        src={apiUrl + "/" + schema}
      >
        {#snippet controls(row: any)}
          <button onclick={() => openFormForRow(row)}>Edit</button>
        {/snippet}
      </DatabaseTable>

      <dialog open={editRow} id="edit-dialog" oncancel={() => cancelDialog()}>
        <article>
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
        </article>
      </dialog>
    {/if}
  </div>
{/if}

<style>
  .database-editor {
    padding: var(--pico-spacing);
  }
</style>
