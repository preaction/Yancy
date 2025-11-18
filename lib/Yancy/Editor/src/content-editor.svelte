<script lang="ts">
  import debounce from "debounce";
  import MdiLoading from "~icons/mdi/loading";
  import MdiCheck from "~icons/mdi/check";

  let channel = new MessageChannel();
  type YancyIframeMessage = {
    version?: number;
    name: string;
  };
  type YancyInputMessage = YancyIframeMessage & {
    name: "input";
    block: {
      block_id?: number;
      name: string;
      path: string;
      content: string;
    };
  };
  type YancyElement = {
    tag: string;
    class: string;
    style: string;
  };
  type YancyFocusMessage = YancyIframeMessage & {
    name: "focus";
    stack: YancyElement[];
  };

  let saving: boolean = false;
  const saveBlock = async (msg: YancyInputMessage) => {
    console.log("saving block", msg);
    let method = "POST",
      endpoint = "/yancy/api/blocks";
    if (msg.block.block_id) {
      endpoint += "/" + msg.block.block_id;
      method = "PUT";
    }
    delete msg.block.block_id;
    const res = await fetch(endpoint, {
      method,
      body: JSON.stringify(msg.block),
    });
    if (!msg.block.block_id) {
      // Need to tell the page that the ID has changed...
      const block = await res.json();
      channel.port1.postMessage({
        name: "update",
        block,
      });
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
    } else if (e.data.name === "focus") {
      const focusEvent = e.data as YancyFocusMessage;

      // Decide which toolbars to enable
      const textTags = ["p", "h1", "h2", "h3", "h4", "h5", "h6"];
      const textContainers = [...textTags, "y-block"];
      if (textContainers.includes(focusEvent.stack[0].tag)) {
        enableTextToolbar = true;
        const tagStackEntry = focusEvent.stack.find((s) =>
          textTags.includes(s.tag),
        );
        currentTextTag = tagStackEntry?.tag || "p";
      }
    } else if (e.data.name === "blur") {
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
  let currentTextTag: string = "p";
  function updateTextTag(newStyle: string) {
    console.log("updating text style to " + newStyle);
    channel.port1.postMessage({
      name: "style",
      tag: newStyle,
    });
    currentTextTag = newStyle;
  }
</script>

<div class="editor-view">
  <div class="toolbar">
    <div class="text">
      <select
        name="tag"
        bind:value={() => currentTextTag, updateTextTag}
        disabled={!enableTextToolbar}
      >
        <!-- XXX: Should be a popup to show what style looks like -->
        <option value="p">Normal</option>
        <option value="h1">Heading 1</option>
        <option value="h2">Heading 2</option>
        <option value="h3">Heading 3</option>
        <option value="h4">Heading 4</option>
        <option value="h5">Heading 5</option>
        <option value="h6">Heading 6</option>
      </select>
    </div>
    <div class="status">
      {#if saving}
        <span class="spin" title="Saving"><MdiLoading /></span>
      {:else}
        <span class="success" title="Saved"><MdiCheck /></span>
      {/if}
    </div>
  </div>
  <iframe id="content-view" src="/" {onload} title="Content View"></iframe>
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
    height: 2em;
    color: black;
    background: #ccc;
    display: flex;
    align-items: center;
    margin: 0;
    padding: 0;
    border-bottom: 2px outset;
    position: relative;
  }
  .status {
    position: absolute;
    right: 0;
    padding: 0.2em;
  }
</style>
