<script lang="ts">
  import debounce from "debounce";
  import type {
    YancyInputMessage,
    YancyIframeMessage,
    YancyEditMessage,
  } from "./types";
  import { CheckIcon, LoaderPinwheelIcon } from "@lucide/svelte";

  let channel = new MessageChannel();
  let saving: boolean = false;
  let blockId: string | undefined = undefined;
  const saveBlock = async (msg: YancyInputMessage) => {
    console.log("saving block", msg);
    let method = "POST",
      endpoint = "/yancy/api/blocks";
    if (blockId) {
      endpoint += "/" + blockId;
      method = "PUT";
    }
    delete msg.block.block_id;
    const res = await fetch(endpoint, {
      method,
      body: JSON.stringify(msg.block),
    });
    if (!blockId) {
      const block = await res.json();
      blockId = block.block_id;
    }
    saving = false;
  };
  const handleSaveBlock = debounce(saveBlock, 1000);

  const onmessage = (e: MessageEvent<YancyIframeMessage>) => {
    console.debug("got message from iframe", e.data);
    if (e.data.name === "ready") {
      if (typeof e.data.version !== "undefined" && e.data.version < 0) {
        console.error("Yancy iframe version not supported by editor", {
          version: e.data.version,
        });
      }
      console.debug("telling iframe to enable editing");
      channel.port1.postMessage({ version: 0, name: "enable" });
    } else if (e.data.name === "input") {
      // Iframe is going to send every message, it's up to the editor to debounce.
      saving = true;
      const inputEvent = e.data as YancyInputMessage;
      handleSaveBlock(inputEvent);
    } else if (e.data.name === "edit") {
      const editEvent = e.data as YancyEditMessage;
      // Editor is now active. Start your engines!
    }
  };

  const onload = (e: Event) => {
    console.debug("editor iframe loaded", e);
    channel = new MessageChannel();
    channel.port1.onmessage = onmessage;
    // Initialize the editor interface by sending the page a MessagePort to use
    if (e.target instanceof HTMLIFrameElement && e.target.contentWindow) {
      e.target.contentWindow.postMessage("Yancy.init", "*", [channel.port2]);
    }
  };

  let iframe: HTMLIFrameElement;
  export function navigate(url: string) {
    iframe.src = url;
  }
</script>

<div class="editor-view">
  <nav class="w-full flex justify-between p-1">
    <div>
      &nbsp;
      <!-- TODO:
        <span>Route Name/Slug</span>
        <span>Dropdown of block names, select to focus</span>
      -->
    </div>
    <div>
      &nbsp;
      <!-- TODO: route schema / filter / example item -->
    </div>
    <div role="status">
      {#if saving}
        <LoaderPinwheelIcon
          title="Saving..."
          class="stroke-primary-500 animate-spin"
        />
      {:else}
        <CheckIcon title="Saved" class="stroke-success-500" />
      {/if}
    </div>
  </nav>
  <iframe
    bind:this={iframe}
    id="content-view"
    src="/"
    {onload}
    title="Content View"
  ></iframe>
</div>

<style>
  .editor-view {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
  }
  #content-view {
    box-sizing: border-box;
    flex: 1 1 auto;
    width: 100%;
  }
</style>
