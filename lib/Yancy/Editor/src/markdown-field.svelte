<script lang="ts">
  import { marked } from "marked";
  import type { AriaAttributes } from "svelte/elements";
  let {
    id,
    value = "",
    oninput,
    error,
    ...rest
  }: {
    id: string;
    value: string;
    oninput: (newValue: string) => void;
    error: any;
  } & AriaAttributes = $props();
  let showHtml: boolean = $state(false);
</script>

<div>
  {#if error}
    <span id={id + "-error"}>{error.$errors[0].message}</span>
  {/if}
  <div>
    <button
      type="button"
      onclick={() => {
        showHtml = !showHtml;
      }}>Preview</button
    >
  </div>
  <div>
    <textarea
      {...rest}
      {value}
      oninput={(e) => oninput((e.target as HTMLTextAreaElement).value)}
      {id}
      class={showHtml ? "hidden" : ""}
      placeholder="Markdown content"
      aria-invalid={!!error}
      aria-errormessage={error ? id + "-error" : null}
    ></textarea>
    <div data-testid="markdown-preview" class={!showHtml ? "hidden" : ""}>
      {@html marked(value)}
    </div>
  </div>
</div>

<style>
  .hidden {
    display: none;
  }
</style>
