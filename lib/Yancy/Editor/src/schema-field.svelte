<script lang="ts">
  import type { YancySchema } from "./types.d.ts";
  import MarkdownField from "./markdown-field.svelte";
  import FileField from "./file-field.svelte";
  import type { AriaAttributes } from "svelte/elements";

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
    value ? JSON.parse(JSON.stringify(value)) : undefined,
  );
  let type = $derived(
    Array.isArray(schema.type) ? schema.type[0] : schema.type,
  );

  function updateValue(value: any) {
    newValue = value;
    onchange(newValue);
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
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
      disabled={schema.readOnly}
      value={newValue ?? ""}
      oninput={(e) => updateField(e)}
    ></textarea>
    {#if error}
      <small id={id + "-error"}>{error.$errors[0].message}</small>
    {/if}
  {:else if type == "boolean"}
    <input
      type="checkbox"
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
