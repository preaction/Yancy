<script lang="ts">
  import { onMount, onDestroy } from "svelte";
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

  let markMenu: HTMLElement | undefined = $state();
  let nodeMenu: HTMLElement | undefined = $state();
  let element: HTMLElement | undefined = $state();
  let editorState: { editor: Editor | null } = $state({ editor: null });
  let { onUpdate, content } = $props();

  onMount(() => {
    console.log("Creating svelte-based Editor");
    editorState.editor = new Editor({
      element,
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
      content,
      onTransaction: ({ editor }) => {
        // Update the state signal to force a re-render
        editorState = { editor };
      },
      onUpdate,
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

<div style="position: relative" data-theme="vintage">
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
            <Menu.Content data-theme="vintage">
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

  <div bind:this={element}></div>
</div>

<style>
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
</style>
