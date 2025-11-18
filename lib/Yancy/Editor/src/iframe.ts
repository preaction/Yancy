const Yancy = (window.Yancy ??= {
  allowOrigins: ["http://localhost:3000"],
});

type YancyEditorMessage = {
  name: string;
};
type YancyUpdateMessage = YancyEditorMessage & {
  name: "update";
  block?: {
    block_id?: number;
    name: string;
    path: string;
    content: string;
  };
};

function handleBlockInput(e: InputEvent) {
  if (!(e.target instanceof HTMLElement)) {
    return;
  }
  console.debug("block input event", e);
  const blockEl = e.target;
  const blockData = {
    block_id: blockEl.getAttribute("block_id"),
    name: blockEl.getAttribute("name"),
    path: window.location.pathname,
    content: blockEl.innerHTML,
  };
  Yancy.editorPort.postMessage({
    name: "input",
    block: blockData,
  });
}

function handleEvent(e: MessageEvent<YancyEditorMessage>) {
  console.debug("got message from editor", e);
  if (e.data.name === "enable") {
    for (const block of Array.from(document.querySelectorAll("y-block"))) {
      if (block instanceof HTMLElement) {
        block.contentEditable = "true";
        block.addEventListener("input", handleBlockInput);
      }
    }
  } else if (e.data.name === "update") {
    // An element was updated, so lets find and update it...
    const updateEvent = e.data as YancyUpdateMessage;
    if (updateEvent.block) {
      console.debug("updating block", updateEvent.block);
      const block = document.querySelector(
        `y-block[name=${updateEvent.block.name}]`,
      );
      block.setAttribute("block_id", "" + updateEvent.block.block_id);
    }
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
