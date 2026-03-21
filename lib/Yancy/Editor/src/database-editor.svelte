<script lang="ts">
  import type { YancySchema, YancyListQuery } from "./types";
  import { marked } from "marked";
  import DatabaseTable from "./database-table.svelte";
  import { tick } from "svelte";
  import ObjectField from "./object-field.svelte";

  let {
    src,
    schema,
    query,
  }: { src: string; schema: string; query: YancyListQuery } = $props();
  const apiUrl = src + "/api";
  const storageUrl = src + "/storage";

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

  // The row we are currently editing, unchanged
  let editRow: any = $state();
  // The row we are currently editing, with changes
  let changedRow: any = $state();

  // Errors by field
  let fieldErrors: any = $state({});
  // Errors not attached to any field
  let objectErrors: any = $state([]);

  let hasError = $derived(
    Object.keys(fieldErrors).length > 0 || objectErrors.length > 0,
  );

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
    changedRow = JSON.parse(JSON.stringify(editRow));

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

  async function saveRow(e: Event) {
    // Since we're doing this as a form submit handler, we cannot perform the
    // default action of actually submitting the form to the backend.
    // I tried using <form method="dialog">, but that seemed to always close
    // the dialog after the form submission...
    e.preventDefault();

    const row = changedRow;
    fieldErrors = {};
    objectErrors = [];

    let url = apiUrl + "/" + schema;
    // If some ID fields are not read-only, we need to use the old value in the
    // URL, and the new value in the form body.
    if (dataSchema.idFields.every((k) => editRow[k])) {
      url += "/" + dataSchema.idFields.map((k) => editRow[k]).join("/");
    }

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
      // Build the error structure so we can show errors next to the fields
      const error = await res.json();
      console.error(error);
      if (error.errors && Array.isArray(error.errors)) {
        for (const err of error.errors) {
          if (!err.path || typeof err.path !== "string" || err.path === "/") {
            // Not a field error, so add it to the generic pile
            objectErrors.push(err.message);
            continue;
          }
          if (typeof err.path === "string") {
            const pathParts = err.path.split("/").slice(1);
            let fieldErr = fieldErrors;
            for (const part of pathParts) {
              fieldErr[part] ??= {};
              fieldErr = fieldErr[part];
            }
            fieldErr.$errors ??= [];
            fieldErr.$errors.push(err);
          }
        }
      }
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
    console.log("closeDialog");
    editRow = undefined;
    changedRow = undefined;
    const dialog = document.getElementById("edit-dialog") as
      | HTMLDialogElement
      | undefined;
    if (dialog) {
      dialog.requestClose();
    }
  }

  /**
   * Cancel editing whatever is in the dialog. Show a pop-up if whatever has
   * been edited and user would lose changes.
   */
  function cancelDialog() {
    console.log("cancelDialog");
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
        {query}
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
          <form
            id="edit-form"
            aria-labelledby="edit-item-heading"
            onsubmit={saveRow}
          >
            {#if hasError}
              <div role="alert" aria-describedby="error-description">
                <span id="error-description">Error</span>
                {#if objectErrors.length > 0}
                  <ul>
                    {#each objectErrors as error}
                      <li>{error}</li>
                    {/each}
                  </ul>
                {/if}
              </div>
            {/if}
            <ObjectField
              storage={storageUrl}
              schema={dataSchema.schema}
              value={changedRow}
              errors={fieldErrors}
              onchange={(newValue) => {
                changedRow = newValue;
              }}
            />
            <button>Save</button>
            <button
              type="button"
              commandfor="edit-dialog"
              command="request-close">Cancel</button
            >
          </form>
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
