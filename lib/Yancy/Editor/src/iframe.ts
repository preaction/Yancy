import { Editor } from "@tiptap/core";
import { YancyCommandMessage } from "./types.js";
import ContentField from "./content-field.svelte";
import { mount } from "svelte";
import "./iframe.css";

const Yancy = (window.Yancy ??= {
  allowOrigins: ["http://localhost:3000"],
});

type YancyEditorMessage = {
  name: string;
};

/**
 * A map of block name to the editor instances for that block.
 */
let blockEditors: Map<string, Editor> = new Map();
/**
 * The name of the block that is currently focused (or, strictly, whose
 * editor has focus somewhere inside.)
 */
let focusedBlock: string = "";

/**
 * Get the Tiptap Editor instance currently in-focus, if any.
 */
function getFocusedEditor(): Editor {
  return blockEditors.get(focusedBlock);
}

function startEditor(block: HTMLElement) {
  const blockId = block.getAttribute("block_id");
  const blockName = block.getAttribute("name");

  // Get the content for the editor
  const content = block.innerHTML;
  // Clear out the existing content so the editor can replace it
  block.replaceChildren();
  mount(ContentField, {
    target: block,
    props: {
      content,
      onUpdate({ editor }) {
        const blockData = {
          block_id: blockId,
          name: blockName,
          path: window.location.pathname,
          content: editor.getHTML(),
        };
        Yancy.editorPort.postMessage({
          name: "input",
          block: blockData,
        });
      },
    },
  });
}

function handleBodyClick(e: PointerEvent) {
  const el = e.target as HTMLElement;
  const block = el.closest("y-block") as HTMLElement;
  focusedBlock = block ? block.getAttribute("name") : "";
}

function enableEditing() {
  // Set up all the necessary Tiptap instances
  for (const block of document.querySelectorAll("y-block")) {
    if (!(block instanceof HTMLElement)) {
      continue;
    }
    startEditor(block);
  }

  window.addEventListener("click", handleBodyClick);
}

function handleEvent(e: MessageEvent<YancyEditorMessage>) {
  console.debug("got message from editor", e);
  if (e.data.name === "enable") {
    enableEditing();
  } else if (e.data.name === "command" && focusedBlock) {
    // Fire command in editor
    const commandEvent = e.data as YancyCommandMessage;
    let chain = getFocusedEditor().chain();
    for (const c of commandEvent.command) {
      const [method, ...args] = typeof c === "string" ? [c] : c;
      chain = chain[method](...args);
    }
    chain.run();
  }
}

window.addEventListener("message", (e: MessageEvent) => {
  console.debug("got window message", e);
  if (!Yancy.allowOrigins.find((o) => e.origin.match(o))) {
    console.error(`origin ${e.origin} not allowed.`, {
      allowOrigins: Yancy.allowOrigins,
    });
  }

  // Handle Yancy editor initialization request
  const [, , version] = e.data.split(/:/);
  if (version < 0) {
    console.error("Yancy editor version not supported by iframe", { version });
    return;
  }
  Yancy.editorPort = e.ports[0];
  Yancy.editorPort.onmessage = handleEvent;
  console.debug('sending "ready" message');
  Yancy.editorPort.postMessage({ version: 0, name: "ready" });
});
