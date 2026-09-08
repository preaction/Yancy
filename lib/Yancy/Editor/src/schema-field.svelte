<script lang="ts">
  import type { YancySchema } from "./types.d.ts";
  import MarkdownField from "./markdown-field.svelte";
  import FileField from "./file-field.svelte";
  import SchemaField from "./schema-field.svelte";
  import type { AriaAttributes } from "svelte/elements";
  import ArrayField from "./array-field.svelte";
  import ContentField from "./content-field.svelte";

  function isNumberType(schema: YancySchema): boolean {
    const typeName =
      typeof schema.type == "string"
        ? schema.type
        : Array.isArray(schema.type)
          ? schema.type[0]
          : "";
    return ["number", "integer"].includes(typeName);
  }
  function isFalsey(value: any): boolean {
    if (typeof value == "boolean") {
      return !value;
    } else if (typeof value == "number") {
      return !value;
    } else if (typeof value == "string") {
      return value == "false" || value == "0";
    }
    return false;
  }

  let {
    schema,
    value,
    error,
    storage,
    onchange = () => ({}),
    name,
    id = name,
    testid,
    ...rest
  }: {
    schema: YancySchema;
    value?: any;
    error?: any;
    storage: string;
    onchange?: (newValue: any) => void;
    name: string;
    id: string;
    testid?: string;
  } & AriaAttributes = $props();

  let attrs = $derived({
    ...(name ? { name } : {}),
    ...(id ? { id } : {}),
    ...(testid ? { ["data-testid"]: testid } : {}),
    ...rest,
  });
  let newValue = $derived(
    value
      ? schema.contentMediaType === "application/json"
        ? JSON.parse(value)
        : JSON.parse(JSON.stringify(value))
      : undefined,
  );
  let type = $derived(
    Array.isArray(schema.type) ? schema.type[0] : schema.type,
  );

  function updateValue(value: any) {
    newValue = value;
    onchange(
      schema.contentMediaType === "application/json"
        ? JSON.stringify(newValue)
        : newValue,
    );
  }

  function updateField(e: Event) {
    updateValue((e.target as HTMLInputElement).value);
  }
  function updateNumberField(e: Event) {
    const newText = (e.target as HTMLInputElement).value;
    if (!newText) {
      return;
    }
    const newNumber = parseFloat(newText);
    if (!isNaN(newNumber)) {
      updateValue(newNumber);
    } else {
      // Set the bad value so we can get the error when we try to submit
      updateValue(newText);
    }
  }
</script>

<div>
  {#if type == "string" && schema.format == "textarea"}
    <textarea
      {...attrs}
      class="textarea"
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      disabled={schema.readOnly}
      value={newValue ?? ""}
      oninput={(e) => updateField(e)}
    ></textarea>
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.contentMediaType == "application/json"}
    <SchemaField
      {...attrs}
      {storage}
      schema={schema.schema}
      value={newValue}
      disabled={schema.readOnly}
      onchange={updateValue}
    />
  {:else if type == "string" && schema.contentMediaType == "text/html"}
    <!-- TODO: Add "full screen" button -->
    <ContentField
      class="w-auto min-w-2xl min-h-60 overflow-auto bg-surface-50-950 color-surface-950-50 inset-ring rounded-md p-1 inset-ring-surface-300-700 shadow-surface-300-700 focus-within:inset-ring-primary-500 focus-within:shadow-primary-500"
      {...attrs}
      label={schema.title || name}
      value={newValue}
      disabled={schema.readOnly}
      oninput={updateValue}
    />
  {:else if type == "array"}
    <ArrayField
      {...attrs}
      {storage}
      {schema}
      value={newValue}
      disabled={schema.readOnly}
      onchange={updateValue}
    />
  {:else if type == "boolean"}
    <input
      type="checkbox"
      class="checkbox"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      checked={!isFalsey(newValue)}
      disabled={schema.readOnly}
      onchange={(e: Event) => {
        updateValue((e.target as HTMLInputElement)?.checked);
      }}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if schema.enum}
    <select
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      class="select"
      value={newValue}
      disabled={schema.readOnly}
      onchange={(e) => {
        updateValue((e.target as HTMLSelectElement).value);
      }}
    >
      {#each schema.enum as enumValue}
        <option>{enumValue}</option>
      {/each}
    </select>
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if isNumberType(schema)}
    <input
      type="text"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue ?? 0}
      disabled={schema.readOnly}
      oninput={updateNumberField}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "markdown"}
    <MarkdownField
      {...attrs}
      {error}
      value={newValue ?? ""}
      oninput={updateValue}
    ></MarkdownField>
  {:else if type == "string" && schema.format == "date"}
    <input
      type="date"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue}
      onchange={(e) => updateField(e)}
      disabled={schema.readOnly}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "date-time"}
    <input
      type="datetime-local"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue}
      onchange={(e) => updateField(e)}
      disabled={schema.readOnly}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "email"}
    <input
      type="email"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue}
      oninput={(e) => updateField(e)}
      disabled={schema.readOnly}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "url"}
    <input
      type="url"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue}
      oninput={(e) => updateField(e)}
      disabled={schema.readOnly}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "tel"}
    <input
      type="tel"
      class="input"
      {...attrs}
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue}
      onchange={(e) => updateField(e)}
      disabled={schema.readOnly}
      oninput={(e) => updateField(e)}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "string" && schema.format == "filepath"}
    <FileField
      {...attrs}
      {error}
      value={newValue}
      disabled={schema.readOnly}
      onchange={updateValue}
      {storage}
    />
  {:else if type == "string"}
    <input
      {...attrs}
      class="input"
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      value={newValue ?? ""}
      oninput={(e) => updateField(e)}
      disabled={schema.readOnly}
    />
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else}
    Unknown type: {type}
  {/if}
</div>
