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
type YancyStyleMessage = YancyEditorMessage & {
  name: "style";
  tag?: string;
  class?: string;
  style?: string;
};

function handleBlockClick(e: PointerEvent) {
  if (!(e.target instanceof HTMLElement)) {
    return;
  }
  console.debug("block click event", e);
  const msg = {
    name: "focus",
    stack: [],
  };
  let el = e.target;
  while (el) {
    msg.stack.push({
      tag: el.tagName.toLowerCase(),
      class: el.className,
      style: el.style.cssText,
    });
    el = el.parentElement;
  }
  Yancy.editorPort.postMessage(msg);
  e.stopPropagation();
}

function sendInputMessage(blockEl: HTMLElement) {
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

function handleBlockInput(e: InputEvent) {
  if (!(e.target instanceof HTMLElement)) {
    return;
  }
  console.debug("block input event", e);
  sendInputMessage(e.target);
}

function handleBodyClick(e: PointerEvent) {
  // We can click on the window without technically removing
  // focus from one of the contenteditable elements, so make
  // sure we don't still have a good focus...
  if (document.activeElement.closest("[contenteditable]")) {
    return;
  }
  const msg = {
    name: "blur",
  };
  Yancy.editorPort.postMessage(msg);
}

function handleEvent(e: MessageEvent<YancyEditorMessage>) {
  console.debug("got message from editor", e);
  if (e.data.name === "enable") {
    window.addEventListener("click", handleBodyClick);
    for (const block of Array.from(document.querySelectorAll("y-block"))) {
      if (block instanceof HTMLElement) {
        block.contentEditable = "true";
        block.addEventListener("input", handleBlockInput);
        block.addEventListener("click", handleBlockClick);
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
      block.innerHTML = updateEvent.block.content;
    }
  } else if (e.data.name === "style") {
    const styleEvent = e.data as YancyStyleMessage;
    const sel = getSelection();
    console.log("selection at start", sel);
    if (!sel) {
      console.error("Cannot update style: No selection");
      return;
    }
    console.debug("changing style", styleEvent);
    // If we're in a bare text node (parent node is not a text style),
    // pretend we're in a <p> node that surrounds all the text
    // we can reach from where we are without crossing another
    // element node.
    const anchorNode = sel.anchorNode;
    const inText = !(anchorNode instanceof HTMLElement);
    // Just gotta change the tag name of our parent element?
    const oldParent = inText ? anchorNode.parentElement : anchorNode;
    const blockEl = oldParent.closest("y-block") as HTMLElement;
    const textStyles = ["p", "h1", "h2", "h3", "h4", "h5", "h6"];
    if (!textStyles.includes(oldParent.tagName.toLowerCase())) {
      console.log("adding wrapper around current text...");
      const textNodes = [anchorNode];
      let testNode = anchorNode.previousSibling;
      while (testNode && testNode.nodeType !== Node.ELEMENT_NODE) {
        textNodes.unshift(testNode);
        testNode = testNode.previousSibling;
      }
      testNode = anchorNode.nextSibling;
      while (testNode && testNode.nodeType !== Node.ELEMENT_NODE) {
        textNodes.push(testNode);
        testNode = testNode.nextSibling;
      }
      const parentNode = anchorNode.parentNode;
      const newParent = document.createElement(styleEvent.tag);
      console.log(
        "Wrapping text nodes",
        textNodes,
        "parent",
        parentNode,
        "nextSibling",
        testNode,
      );
      newParent.append(...textNodes);
      parentNode.insertBefore(newParent, testNode);

      // Need to fix the selection now that we've changed everything
      sel.setPosition(
        inText ? newParent.childNodes[0] : newParent,
        sel.anchorOffset,
      );
    } else {
      const newParent = document.createElement(styleEvent.tag);
      newParent.append(...Array.from(oldParent.childNodes));
      oldParent.replaceWith(newParent);

      // Need to fix the selection now that we've changed everything
      sel.setPosition(
        inText ? newParent.childNodes[0] : newParent,
        sel.anchorOffset,
      );
    }
    console.log("selection at end", sel);
    sendInputMessage(blockEl);
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
