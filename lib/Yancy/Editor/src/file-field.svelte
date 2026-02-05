<script lang="ts">
  import type { HTMLInputAttributes } from "svelte/elements";
  let {
    storage = "storage",
    onchange,
    value,
    ...rest
  }: {
    storage?: string;
    onchange: (newValue: string) => void;
  } & HTMLInputAttributes = $props();

  async function uploadFile(e: Event) {
    // Get the element and upload the file to storage
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }
    const res = await fetch(`${storage}/${file.name}`, {
      method: "PUT",
      body: file,
    });
    if (!res.ok) {
      // XXX: Show error
      return;
    }
    onchange(file.name);
  }
</script>

<div>
  <span>{value}</span>
  <input type="file" onchange={(e) => uploadFile(e)} {...rest} />
</div>

<style>
</style>
