<script lang="ts">
  import ContentEditor from "./content-editor.svelte";
  import DatabaseEditor from "./database-editor.svelte";
  import { onMount } from "svelte";
  import type { YancySchema } from "./types";

  type tabName = "website" | "database";
  let base: string = window.Yancy.base;
  function tabFromUrl(url: string): [tabName, string[]] {
    let [, tab, ...rest] = url
      .replace(location.origin, "")
      .replace(base, "")
      .split("/");
    if (tab !== "database") {
      tab = "website";
    }
    return [tab as "website" | "database", rest];
  }

  const [locationTab, locationRest] = tabFromUrl(location.toString());
  history.replaceState({ tab: locationTab, rest: locationRest }, "");

  let currentTab: tabName = $state(locationTab);
  let currentSchema = $state(locationTab === "database" ? locationRest[0] : "");
  let contentEditor: ContentEditor | undefined = $state();

  window.addEventListener("popstate", (e: PopStateEvent) => {
    const { tab, rest } = e.state as {
      tab: tabName;
      rest: string[];
    };
    currentTab = tab;
    if (tab === "database") {
      currentSchema = rest[0];
    } else if (contentEditor) {
      contentEditor.navigate(rest.join("/") || "/");
    }
    e.preventDefault();
    e.stopPropagation();
  });

  document.addEventListener("click", (e: PointerEvent) => {
    let el = e.target;
    if (!el || !(el instanceof Element)) {
      return;
    }
    if (!(el instanceof HTMLAnchorElement)) {
      el = el.closest("a[href]");
      if (!el || !(el instanceof HTMLAnchorElement)) {
        return;
      }
    }
    if (
      el.href &&
      (el.href.startsWith(base) || el.href.startsWith(location.origin + base))
    ) {
      // Internal navigation, hijack it!
      const [, tab, ...rest] = el.href
        .replace(location.origin, "")
        .replace(base, "")
        .split("/");
      if (tab === "website" || tab === "database") {
        currentTab = tab;
        if (tab === "database") {
          currentSchema = rest[0];
        } else if (contentEditor) {
          contentEditor.navigate("/" + rest.join("/"));
        }

        // Mess with history
        history.pushState({ tab, rest }, "", el.href);
        e.stopPropagation();
        e.preventDefault();
      }
    }
  });

  type YancyList<T> = {
    items: T[];
    offset: number;
    total: number;
  };
  type Page = {
    pattern: string;
    name: string;
  };

  let pages: Page[] = $state([]);
  onMount(async () => {
    const res = await fetch(base + "/api/pages");
    const list = (await res.json()) as YancyList<Page>;
    pages = list.items.sort((a, b) =>
      a.pattern < b.pattern ? -1 : a.pattern === b.pattern ? 0 : 1,
    );
  });

  let databaseSchema: Array<[string, YancySchema]> = $state([]);
  onMount(async () => {
    const res = await fetch(base + "/api");
    const apiSchema = await res.json();
    databaseSchema = Object.entries(apiSchema);
    databaseSchema = databaseSchema.sort((a, b) => {
      const aTitle = a[1].title?.toLowerCase() || a[0];
      const bTitle = b[1].title?.toLowerCase() || b[0];
      return aTitle > bTitle ? 1 : aTitle < bTitle ? -1 : 0;
    });
  });
</script>

<div class="yancy-editor">
  <aside>
    <nav class="yancy-accordion">
      <h2 id="website-tree-button">Website</h2>
      <ul
        id="website-tree"
        class="accordion-panel"
        aria-labelledby="website-tree-button"
      >
        {#each pages as page}
          <li>
            <a href={base + "/website" + page.pattern}>
              <span>{page.name}</span> <small>{page.pattern}</small></a
            >
          </li>
        {/each}
      </ul>
      <h2 id="database-button">Database</h2>
      <ul
        id="database-list"
        class="accordion-panel"
        aria-labelledby="database-button"
      >
        {#each databaseSchema as [schemaName, schema]}
          <li>
            <a href={base + "/database/" + schemaName}
              ><span>{schema.title || schemaName}</span></a
            >
          </li>
        {/each}
      </ul>
    </nav>
  </aside>
  <main>
    <div class="main-container">
      {#if currentTab == "website"}
        <ContentEditor bind:this={contentEditor}></ContentEditor>
      {:else if currentTab == "database"}
        <DatabaseEditor src={base} schema={currentSchema}></DatabaseEditor>
      {/if}
    </div>
  </main>
</div>

<style>
  :global(html, body, #app) {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
  }
  .yancy-editor {
    display: flex;
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
  }
  .yancy-editor > aside {
    flex: 0 1 20%;
    overflow-y: scroll;
  }
  .yancy-editor > main {
    flex: 0 1 100%;
    overflow: hidden;
  }

  .yancy-accordion {
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border-right: 2px solid;
  }
  aside nav.yancy-accordion > h2 {
    background: #ccc;
    color: hsl(0deg 0% 13%);
    font-size: 1.2rem;
    font-weight: normal;
    text-decoration: none;
    display: block;
    position: relative;
    margin: 0;
    padding: calc(var(--pico-nav-element-spacing-vertical) * 0.5)
      var(--pico-nav-element-spacing-horizontal);
    text-align: left;
    width: 100%;
    outline: none;
    border: 2px outset;
    border-width: 2px 0;
  }
  aside nav.yancy-accordion li a {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-left: 0;
  }

  aside nav ul {
    margin-left: calc(var(--pico-nav-link-spacing-horizontal) * -1);
    margin-right: 0;
  }

  .yancy-accordion > .accordion-panel {
    flex: 0 1 100%;
  }
  .main-container {
    width: 100%;
    height: 100%;
  }
</style>
