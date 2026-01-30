<script lang="ts">
  import { marked } from "marked";
  let { id, value = $bindable("") }: { id: string; value: string } = $props();
  let showHtml: boolean = $state(false);
</script>

<div>
  <div>
    <button
      onclick={() => {
        showHtml = !showHtml;
      }}>Preview</button
    >
  </div>
  <div>
    <textarea
      bind:value
      {id}
      class={showHtml ? "hidden" : ""}
      placeholder="Markdown content"
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
