<script lang="ts">
  import { onMount, onDestroy, tick, untrack } from "svelte";
  import { Menu, Portal, ToggleGroup } from "@skeletonlabs/skeleton-svelte";
  import { Editor } from "@tiptap/core";
  import { StarterKit } from "@tiptap/starter-kit";
  import { shift } from "@floating-ui/dom";
  import {
    BoldIcon,
    CheckIcon,
    ItalicIcon,
    PlusIcon,
    UnderlineIcon,
  } from "@lucide/svelte";
  import type { ClassValue, SvelteHTMLElements } from "svelte/elements";

  let element: HTMLElement | undefined = $state();
  let editorState: { editor: Editor | null } = $state({ editor: null });
  let {
    oninput,
    value,
    id,
    detachToolbar = false,
    name,
    label,
    ...attrs
  }: {
    oninput: (newContent: string) => void;
    value: string;
    id: string;
    detachToolbar: boolean;
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
      extensions: [StarterKit],
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

  const textStyles = [
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
    {
      value: "h3",
      label: "Heading 3",
      apply() {
        editorState.editor?.chain().focus().toggleHeading({ level: 3 }).run();
      },
      isActive() {
        return editorState.editor?.isActive("heading", {
          level: 3,
        });
      },
    },
  ];

  const insertNodes = [
    {
      value: "img",
      label: "Image",
      apply() {
        editorState.editor?.chain().focus().run();
      },
    },
  ];

  let menuOpen = $state(false);
  let onToolbar = $state(false);
  let showToolbar = $derived(
    editorState.editor?.isFocused || menuOpen || onToolbar,
  );
</script>

<div style="position: relative" data-theme="cerberus">
  <Portal disabled={!detachToolbar}>
    <div
      role="toolbar"
      tabindex="0"
      data-theme="cerberus"
      class="top-0 left-0 right-0 bg-surface-100-900 flex flex-row justify-start items-center content-stretch gap-1"
      class:fixed={detachToolbar}
      class:hidden={detachToolbar && !showToolbar}
      onmouseover={() => (onToolbar = true)}
      onfocus={() => (onToolbar = true)}
      onmouseout={() => (onToolbar = false)}
      onblur={() => (onToolbar = false)}
    >
      <!-- Insert menu -->
      <Menu
        onOpenChange={(details) => {
          menuOpen = details.open;
        }}
      >
        <Menu.Trigger>
          {#snippet element(attributes)}
            <button
              aria-label="Insert"
              class="btn btn-sm preset-filled-primary-500"
              {...attributes}><PlusIcon /></button
            >
          {/snippet}
        </Menu.Trigger>
        <Portal>
          <Menu.Positioner>
            <Menu.Content data-theme="cerberus">
              {#each insertNodes as item (item)}
                <Menu.Item value={item.value}>
                  <Menu.ItemText>{item.label}</Menu.ItemText>
                </Menu.Item>
              {/each}
            </Menu.Content>
          </Menu.Positioner>
        </Portal>
      </Menu>

      <span class="vr"></span>

      <!-- Text style menu -->
      <Menu
        onOpenChange={(details) => {
          menuOpen = details.open;
        }}
      >
        <Menu.Trigger>
          {#snippet element(attributes)}
            <button
              aria-label="Text style"
              class="block btn btn-sm preset-outlined-primary-500 w-40 text-left"
              {...attributes}
              >{textStyles.find((n) => n.isActive())?.label ??
                "Body text"}</button
            >
          {/snippet}
        </Menu.Trigger>
        <Portal>
          <Menu.Positioner>
            <Menu.Content data-theme="cerberus">
              {#each textStyles as item (item)}
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

      <span class="vr"></span>

      <button
        type="button"
        aria-label="Bold"
        onclick={() => editorState.editor?.chain().focus().toggleBold().run()}
        class="btn {editorState.editor?.isActive('bold')
          ? 'preset-filled'
          : 'preset-tonal'}"><BoldIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Italic"
        onclick={() => editorState.editor?.chain().focus().toggleItalic().run()}
        class="btn {editorState.editor?.isActive('italic')
          ? 'preset-filled'
          : 'preset-tonal'}"><ItalicIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Underline"
        onclick={() =>
          editorState.editor?.chain().focus().toggleUnderline().run()}
        class="btn {editorState.editor?.isActive('underline')
          ? 'preset-filled'
          : 'preset-tonal'}"><UnderlineIcon class="size-4" /></button
      >
    </div>
  </Portal>

  <!-- The editor itself -->
  <div
    {...attrs}
    class={["flex", "flex-col", "pico", attrs["class"]]}
    bind:this={element}
  ></div>
</div>

<style>
  /* FIXME: This does not seem to make ProseMirror stretch to fill its container... */
  .derp > :global(.ProseMirror) {
    flex: 1 1 100%;
  }
</style>
