<script lang="ts">
  import { onMount, onDestroy, tick } from "svelte";
  import {
    Menu,
    Popover,
    Portal,
    usePopover,
  } from "@skeletonlabs/skeleton-svelte";
  import type { OpenChangeDetails } from "@zag-js/popover";
  import { Color } from "@tiptap/extension-text-style";
  import { ListItem } from "@tiptap/extension-list";
  import { TextStyle } from "@tiptap/extension-text-style";
  import { TextStyleKit } from "@tiptap/extension-text-style";
  import Emoji from "@tiptap/extension-emoji";

  import { Editor } from "@tiptap/core";
  import { StarterKit } from "@tiptap/starter-kit";
  import {
    BoldIcon,
    CheckIcon,
    ItalicIcon,
    LinkIcon,
    ListIcon,
    ListIndentDecreaseIcon,
    ListIndentIncreaseIcon,
    ListOrderedIcon,
    PlusIcon,
    RedoIcon,
    UnderlineIcon,
    UndoIcon,
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
      extensions: [
        TextStyleKit.configure({
          color: {
            types: [TextStyle.name, ListItem.name],
          },
          textStyle: {
            types: [ListItem.name],
          },
        }),
        Emoji.configure({
          enableEmoticons: true,
        }),
        StarterKit.configure({
          link: {
            openOnClick: false,
            HTMLAttributes: {
              rel: null,
            },
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
    {
      value: "blockquote",
      label: "Block quote",
      apply() {
        editorState.editor?.chain().focus().toggleBlockquote().run();
      },
      isActive() {
        return editorState.editor?.isActive("blockquote");
      },
    },
    {
      value: "pre",
      label: "Preformatted",
      apply() {
        editorState.editor?.chain().focus().toggleCodeBlock().run();
      },
      isActive() {
        return editorState.editor?.isActive("codeBlock");
      },
    },
  ];

  const insertNodes = [
    {
      value: "hr",
      label: "Horizontal Rule",
      apply() {
        editorState.editor?.chain().focus().setHorizontalRule().run();
      },
    },
    {
      value: "img",
      label: "Image",
      apply() {
        editorState.editor?.chain().focus().run();
      },
    },
  ];

  const uid = $props.id();
  const linkPopover = usePopover({
    id: uid,
    onOpenChange(details) {
      showLink = details.open;
      if (!details.open) {
        if (!linkHref) {
          editorState.editor?.chain().focus().unsetLink().run();
        } else {
          editorState.editor?.chain().focus().setLink({ href: linkHref }).run();
        }
      }
    },
  });
  let showLink = $state(false);
  let linkHref = $derived(editorState.editor?.getAttributes("link").href);

  let menuOpen = $state(false);
  let onToolbar = $state(false);
  let showToolbar = $derived(
    editorState.editor?.isFocused || menuOpen || onToolbar || showLink,
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
              class="btn-icon btn-icon-base preset-filled-primary-500"
              {...attributes}><PlusIcon /></button
            >
          {/snippet}
        </Menu.Trigger>
        <Portal>
          <Menu.Positioner>
            <Menu.Content data-theme="cerberus">
              {#each insertNodes as item (item)}
                <Menu.Item value={item.value} onclick={() => item.apply()}>
                  <Menu.ItemText>{item.label}</Menu.ItemText>
                </Menu.Item>
              {/each}
            </Menu.Content>
          </Menu.Positioner>
        </Portal>
      </Menu>

      <span class="vr"></span>

      <button
        type="button"
        aria-label="Undo"
        onclick={() => editorState.editor?.chain().focus().undo().run()}
        class="btn-icon btn-icon-base preset-tonal"
        disabled={!editorState.editor?.can().chain().focus().undo().run()}
        ><UndoIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Redo"
        onclick={() => editorState.editor?.chain().focus().redo().run()}
        class="btn-icon btn-icon-base preset-tonal"
        disabled={!editorState.editor?.can().chain().focus().redo().run()}
        ><RedoIcon class="size-4" /></button
      >

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
              class="block btn btn-base preset-tonal w-40 text-left"
              {...attributes}
              >{textStyles.find((n) => n.isActive())?.label ??
                "Body Text"}</button
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
        class="btn-icon btn-icon-base {editorState.editor?.isActive('bold')
          ? 'preset-filled'
          : 'preset-tonal'}"><BoldIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Italic"
        onclick={() => editorState.editor?.chain().focus().toggleItalic().run()}
        class="btn-icon btn-icon-base {editorState.editor?.isActive('italic')
          ? 'preset-filled'
          : 'preset-tonal'}"><ItalicIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Underline"
        onclick={() =>
          editorState.editor?.chain().focus().toggleUnderline().run()}
        class="btn-icon btn-icon-base {editorState.editor?.isActive('underline')
          ? 'preset-filled'
          : 'preset-tonal'}"><UnderlineIcon class="size-4" /></button
      >
      <Popover.Provider value={linkPopover}>
        <Popover.Trigger class="btn-icon btn-icon-base preset-tonal"
          ><LinkIcon /></Popover.Trigger
        >
        <Portal>
          <Popover.Positioner data-theme="cerberus">
            <Popover.Content
              class="card max-w-md p-4 bg-surface-100-900 shadow-xl"
            >
              <Popover.Description>
                <input
                  bind:value={linkHref}
                  class="input"
                  onkeydown={(ev: KeyboardEvent) => {
                    if (ev.key === "Enter") linkPopover().setOpen(false);
                  }}
                />
                <button
                  type="button"
                  onclick={() => {
                    linkPopover().setOpen(false);
                  }}
                  class="btn preset-filled-primary-500">Apply</button
                >
                <button
                  type="button"
                  class="btn preset-tonal"
                  onclick={() => {
                    linkHref = "";
                    linkPopover().setOpen(false);
                  }}>Remove</button
                >
              </Popover.Description>
              <Popover.Arrow
                class="[--arrow-size:--spacing(2)] [--arrow-background:var(--color-surface-100-900)]"
              >
                <Popover.ArrowTip />
              </Popover.Arrow>
            </Popover.Content>
          </Popover.Positioner>
        </Portal>
      </Popover.Provider>
      <span class="vr"></span>

      <button
        type="button"
        aria-label="Bulleted list"
        onclick={() =>
          editorState.editor?.chain().focus().toggleBulletList().run()}
        class="btn-icon btn-icon-base {editorState.editor?.isActive(
          'bulletList',
        )
          ? 'preset-filled'
          : 'preset-tonal'}"><ListIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Ordered list"
        onclick={() =>
          editorState.editor?.chain().focus().toggleOrderedList().run()}
        class="btn-icon btn-icon-base {editorState.editor?.isActive(
          'orderedList',
        )
          ? 'preset-filled'
          : 'preset-tonal'}"><ListOrderedIcon class="size-4" /></button
      >

      <button
        type="button"
        aria-label="Decrease indent"
        onclick={() =>
          editorState.editor?.chain().focus().liftListItem("listItem").run()}
        class="btn-icon btn-icon-base preset-tonal"
        disabled={!editorState.editor?.can().liftListItem("listItem")}
        ><ListIndentDecreaseIcon class="size-4" /></button
      >
      <button
        type="button"
        aria-label="Increase indent"
        onclick={() =>
          editorState.editor?.chain().focus().sinkListItem("listItem").run()}
        class="btn-icon btn-icon-base preset-tonal"
        disabled={!editorState.editor?.can().sinkListItem("listItem")}
        ><ListIndentIncreaseIcon class="size-4" /></button
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
