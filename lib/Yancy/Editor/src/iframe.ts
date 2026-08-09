import { Editor } from "@tiptap/core";
import { Node, ResolvedPos } from "@tiptap/pm/model";
import { Transaction } from "@tiptap/pm/state";
import StarterKit from "@tiptap/starter-kit";
import { YancyCommandMessage, YancyNode } from "./types.js";

const Yancy = (window.Yancy ??= {
  allowOrigins: ["http://localhost:3000"],
});

type YancyEditorMessage = {
  name: string;
};

let editor!: Editor;
let editorHost: HTMLElement | undefined;

function startEditor(block: HTMLElement) {
  console.log("Mounting editor", block);
  editorHost = block;
  editor.commands.setContent(block.innerHTML, {
    emitUpdate: false,
    errorOnInvalidContent: false,
  });
  editorHost.replaceChildren();
  editor.mount(block);
  editor.commands.focus();
  console.log(editor.schema.spec);
  Yancy.editorPort.postMessage({
    name: "edit",
    schema: JSON.parse(JSON.stringify(editor.schema.spec)),
  });
}

function finishEditor() {
  const editorContent = editor.getHTML();
  editor.unmount();
  editorHost.innerHTML = editorContent;
  editorHost = undefined;
  Yancy.editorPort.postMessage({ name: "blur" });
}

function handleBodyClick(e: PointerEvent) {
  if (!editor) {
    console.warn("Editor not initialized yet.");
  }
  const el = e.target as HTMLElement;
  const block = el.closest("y-block") as HTMLElement;
  if (block && editorHost !== block) {
    // Moving the editor to a new place
    if (editorHost) {
      // Finish the existing editor instance
      finishEditor();
    }
    // Start a new editor instance
    startEditor(block);
  } else if (!block && editorHost) {
    // Clicked outside any y-block, so finish the existing editor instance
    finishEditor();
  }
}

function updateResolvedPos(pos: ResolvedPos) {
  const stack: Node[] = [];
  for (let i = pos.depth; i >= 0; i--) {
    stack.push(pos.node(i));
  }

  Yancy.editorPort.postMessage({
    name: "focus",
    stack: stack.map((n): YancyNode => [n.type.name, n.attrs]),
    marks: pos.marks().map((m) => m.type.name),
  });
}

function enableEditing() {
  editor = new Editor({
    element: null,
    extensions: [StarterKit],
    content: null,
    enableContentCheck: true,
    onUpdate({ editor }) {
      const blockData = {
        block_id: editorHost.getAttribute("block_id"),
        name: editorHost.getAttribute("name"),
        path: window.location.pathname,
        content: editor.getHTML(),
      };
      Yancy.editorPort.postMessage({
        name: "input",
        block: blockData,
      });
    },
    onTransaction({ transaction }) {
      updateResolvedPos(transaction.selection.$head);
    },
    onContentError({ editor, error, disableCollaboration }) {
      console.log("Got content error", error);
    },
  });

  window.addEventListener("click", handleBodyClick);
}

function handleEvent(e: MessageEvent<YancyEditorMessage>) {
  console.debug("got message from editor", e);
  if (e.data.name === "enable") {
    enableEditing();
  } else if (e.data.name === "command") {
    // Fire command in editor
    const commandEvent = e.data as YancyCommandMessage;
    let chain = editor.chain();
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
