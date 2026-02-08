<script lang="ts">
  import { marked } from "marked";
  let {
    id,
    value = "",
    oninput,
  }: {
    id: string;
    value: string;
    oninput: (newValue: string) => void;
  } = $props();
  let showHtml: boolean = $state(false);
</script>

<div>
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
      {value}
      oninput={(e) => oninput((e.target as HTMLTextAreaElement).value)}
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
