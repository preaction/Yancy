<script lang="ts">
  import { onMount, onDestroy, tick, untrack } from "svelte";
  import { Menu, Portal } from "@skeletonlabs/skeleton-svelte";
  import { Editor } from "@tiptap/core";
  import { StarterKit } from "@tiptap/starter-kit";
  import BubbleMenu from "@tiptap/extension-bubble-menu";
  import DragHandle from "@tiptap/extension-drag-handle";
  import { shift } from "@floating-ui/dom";
  import {
    BoldIcon,
    CheckIcon,
    ItalicIcon,
    SettingsIcon,
    UnderlineIcon,
  } from "@lucide/svelte";
  import type { ClassValue, SvelteHTMLElements } from "svelte/elements";

  let markMenu: HTMLElement | undefined = $state();
  let nodeMenu: HTMLElement | undefined = $state();
  let element: HTMLElement | undefined = $state();
  let editorState: { editor: Editor | null } = $state({ editor: null });
  let {
    oninput,
    value,
    id,
    name,
    label,
    ...attrs
  }: {
    oninput: (newContent: string) => void;
    value: string;
    id: string;
    name: string;
    label: string;
    attrs: SvelteHTMLElements["div"] & { class: ClassValue };
  } = $props();

  /**
   * True when we're triggering an update cascade. This happens both when a
   * user types in the editor (the editor changes itself) and when the user
   * chooses a different item to edit (the reactive value is changed.) When
   * we're in an update, we do not trigger any other updates: The editor
   * changing its value should cause the reactive value to change, and vice
   * versa, but that must be where it stops or it causes an infinite loop.
   */
  let inUpdate = false;
  $effect(() => {
    if (value && !inUpdate && editorState.editor) {
      inUpdate = true;
      editorState.editor?.commands.setContent($state.snapshot(value), {
        emitUpdate: false,
      });
      tick().then(() => {
        inUpdate = false;
      });
    }
  });

  onMount(() => {
    editorState.editor = new Editor({
      element,
      editorProps: {
        attributes: { id, name, "aria-label": label },
      },
      extensions: [
        StarterKit,
        BubbleMenu.configure({
          element: markMenu,
        }),
        DragHandle.configure({
          // TODO: This should appear while the editor's focus is inside the
          // node, not hover
          // TODO: This isn't a "drag" handle anymore, but fixing the
          // focus/hover will probably mean creating this from scratch
          // anyway...
          render: () => {
            return nodeMenu;
          },
          computePositionConfig: {
            placement: "top-start",
            middleware: [shift({ crossAxis: true })],
          },
        }),
      ],
      content: value,
      onTransaction: ({ editor }) => {
        // Update the state signal to force a re-render
        editorState = { editor };
      },
      onUpdate({ editor }) {
        const newValue = editor.getHTML();
        if (!inUpdate) {
          inUpdate = true;
          oninput(newValue);
          tick().then(() => (inUpdate = false));
        }
      },
    });
  });
  onDestroy(() => {
    editorState.editor?.destroy();
  });

  const nodeOptions = [
    {
      value: "p",
      label: "Body Text",
      apply() {
        editorState.editor?.chain().focus().setParagraph().run();
      },
      isActive() {
        return editorState.editor?.isActive("paragraph");
      },
    },
    {
      value: "h1",
      label: "Heading 1",
      apply() {
        editorState.editor?.chain().focus().toggleHeading({ level: 1 }).run();
      },
      isActive() {
        return editorState.editor?.isActive("heading", {
          level: 1,
        });
      },
    },
    {
      value: "h2",
      label: "Heading 2",
      apply() {
        editorState.editor?.chain().focus().toggleHeading({ level: 2 }).run();
      },
      isActive() {
        return editorState.editor?.isActive("heading", {
          level: 2,
        });
      },
    },
  ];
</script>

<div style="position: relative" data-theme="cerberus">
  <div
    bind:this={nodeMenu}
    class="inline-flex"
    style="visibility:hidden; z-index: 10;"
  >
    <nav class="btn-group preset-filled-surface-100-900 flex-row gap-0">
      <Menu>
        <Menu.Trigger>
          {#snippet element(attributes)}
            <button class="btn btn-sm preset-filled-primary-500" {...attributes}
              ><SettingsIcon /></button
            >
          {/snippet}
        </Menu.Trigger>
        <Portal>
          <Menu.Positioner>
            <Menu.Content data-theme="cerberus">
              {#each nodeOptions as item (item)}
                <Menu.OptionItem
                  type="radio"
                  checked={item.isActive() ?? false}
                  onCheckedChange={(checked) => (checked ? item.apply() : null)}
                  value={item.value}
                >
                  <Menu.ItemText>{item.label}</Menu.ItemText>
                  <Menu.ItemIndicator class="hidden data-[state=checked]:block">
                    <CheckIcon class="size-4" />
                  </Menu.ItemIndicator>
                </Menu.OptionItem>
              {/each}
            </Menu.Content>
          </Menu.Positioner>
        </Portal>
      </Menu>
    </nav>
  </div>

  <div
    bind:this={markMenu}
    style="visibility:hidden; position: absolute; z-index: 20;"
  >
    {#if editorState.editor}
      <nav class="btn-group preset-filled-surface-100-900 flex-row gap-0">
        <button
          type="button"
          class="btn m-0 ms-1 rounded-none rounded-s-md"
          class:active={editorState.editor?.isActive("bold")}
          onclick={editorState.editor?.chain().focus().toggleBold().run}
        >
          <BoldIcon />
        </button>
        <button
          type="button"
          class="btn m-0 rounded-none"
          class:active={editorState.editor?.isActive("italic")}
          onclick={editorState.editor?.chain().focus().toggleItalic().run}
        >
          <ItalicIcon />
        </button>
        <button
          type="button"
          class="btn m-0 me-1 rounded-none rounded-e-md"
          class:active={editorState.editor?.isActive("underline")}
          onclick={editorState.editor?.chain().focus().toggleUnderline().run}
        >
          <UnderlineIcon />
        </button>
      </nav>
    {/if}
  </div>

  <div
    {...attrs}
    class={["flex", "flex-col", "derp", attrs["class"]]}
    bind:this={element}
  ></div>
</div>

<style>
  /* FIXME: This is required to get the editor navs to have the same theme
   * as the rest of the editor when embedded in the site.
   * Instead, we probably need to do something with shadow DOMs and injecting a
   * stylesheet of some kind...
   */
  @reference "./iframe.css";
  button {
    @apply btn btn-sm m-0 p-1;
    background-color: light-dark(
      var(--color-root-bg-light),
      var(--color-root-bg-dark)
    );
    color: light-dark(
      var(--typo-base--color-light),
      var(--typo-base--color-dark)
    );
    @apply preset-outlined-primary-500;

    &.active {
      @apply preset-filled-primary-500;
    }
    &.rounded-none {
      @apply rounded-none;
    }
    &.rounded-e-md {
      @apply rounded-e-md;
    }
    &.rounded-s-md {
      @apply rounded-s-md;
    }
  }

  /* FIXME: This does not seem to make ProseMirror stretch to fill its container... */
  .derp > :global(.ProseMirror) {
    flex: 1 1 100%;
  }
</style>
