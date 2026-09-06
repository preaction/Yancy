<script lang="ts">
  import debounce from "debounce";
  import MdiLoading from "~icons/mdi/loading";
  import MdiCheck from "~icons/mdi/check";
  import type {
    YancyInputMessage,
    YancyIframeMessage,
    YancyEditMessage,
    YancyFocusMessage,
    YancyCommandMessage,
    YancyNode,
  } from "./types";

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
    } else if (e.data.name === "focus") {
      const focusEvent = e.data as YancyFocusMessage;

      // Decide which toolbars to enable
      currentNode = focusEvent.stack[0][0];
      if (currentNode === "heading") {
        currentNode += "-" + focusEvent.stack[0][1]?.level;
      }
      console.log("Current node is now", currentNode);

      // Decide which buttons should be "active"
      const textTags = ["paragraph", "heading"];
      const textContainers = [...textTags, "doc"];
      if (textContainers.includes(focusEvent.stack[0][0])) {
        enableTextToolbar = true;
      }
    } else if (e.data.name === "blur") {
      currentNode = "paragraph";
      enableTextToolbar = false;
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

  let enableTextToolbar: boolean = false;
  const nodeMap: { [key: string]: YancyNode } = {
    paragraph: ["paragraph"],
    "heading-1": ["heading", { level: 1 }],
    "heading-2": ["heading", { level: 2 }],
    "heading-3": ["heading", { level: 3 }],
    "heading-4": ["heading", { level: 4 }],
    "heading-5": ["heading", { level: 5 }],
    "heading-6": ["heading", { level: 6 }],
  };
  let currentNode: keyof typeof nodeMap = "paragraph";
  function updateNode(newNode: string) {
    console.log("updating node to " + newNode);
    channel.port1.postMessage({
      name: "command",
      command: [["setNode", ...nodeMap[newNode]]],
    } as YancyCommandMessage);
    currentNode = newNode;
  }

  let iframe: HTMLIFrameElement;
  export function navigate(url: string) {
    iframe.src = url;
  }
</script>

<div class="editor-view">
  <nav class="toolbar">
    <div class="text">
      <select
        name="tag"
        bind:value={() => "" + currentNode, updateNode}
        disabled={!enableTextToolbar}
      >
        <!-- XXX: Should be a popup to show what style looks like -->
        <option value="paragraph">Normal</option>
        <option value="heading-1">Heading 1</option>
        <option value="heading-2">Heading 2</option>
        <option value="heading-3">Heading 3</option>
        <option value="heading-4">Heading 4</option>
        <option value="heading-5">Heading 5</option>
        <option value="heading-6">Heading 6</option>
      </select>
    </div>
    <div role="status">
      {#if saving}
        <span class="spin" title="Saving"><MdiLoading /></span>
      {:else}
        <span class="success" title="Saved"><MdiCheck /></span>
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
  .spin {
    animation: spin 1s linear infinite;
    display: inline-block;
  }
  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }
  .success {
    color: green;
  }
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
  .toolbar {
    width: 100%;
    color: black;
    background: #ccc;
    display: flex;
    align-items: center;
    margin: 0;
    padding: 0;
    border-top: 2px outset;
    border-bottom: 2px outset;
    position: relative;
  }
  .toolbar * {
    margin-bottom: 0;
  }
  .toolbar select {
    padding: calc(var(--pico-form-element-spacing-vertical) * 0.5)
      var(--pico-form-element-spacing-horizontal);
  }
  .status {
    position: absolute;
    right: 0;
    padding: 0.2em;
  }
</style>
