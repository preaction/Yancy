<script lang="ts">
  import ContentTree from "./content-tree.svelte";
  import ContentEditor from "./content-editor.svelte";
  import DatabaseList from "./database-list.svelte";
  import DatabaseEditor from "./database-editor.svelte";

  let currentTab: "content" | "database" = $state("content");
  let currentSchema = $state("");
</script>

<div class="yancy-editor">
  <aside>
    <nav class="yancy-accordion">
      <h2 id="content-tree-button">
        <button
          onclick={() => (currentTab = "content")}
          aria-controls="content-tree"
          aria-expanded={currentTab == "content"}>Content</button
        >
      </h2>
      <section
        id="content-tree"
        class="accordion-panel"
        aria-labelledby="content-tree-button"
      >
        <ContentTree onselect={() => (currentTab = "content")}></ContentTree>
      </section>
      <h2 id="database-button">
        <button
          onclick={() => (currentTab = "database")}
          aria-controls="database-list"
          aria-expanded={currentTab == "database"}>Database</button
        >
      </h2>
      <section
        id="database-list"
        class="accordion-panel"
        aria-labelledby="database-button"
      >
        <DatabaseList
          onselect={(schema: string) => {
            currentTab = "database";
            currentSchema = schema;
          }}
        ></DatabaseList>
      </section>
    </nav>
  </aside>
  <main>
    <div class="main-container">
      {#if currentTab == "content"}
        <ContentEditor></ContentEditor>
      {:else if currentTab == "database"}
        <DatabaseEditor schema={currentSchema}></DatabaseEditor>
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
  .yancy-accordion > h2 {
    margin: 0;
    padding: 0;
  }
  .yancy-accordion > h2 button {
    background: #ccc;
    color: hsl(0deg 0% 13%);
    display: block;
    font-size: 1rem;
    font-weight: normal;
    margin: 0;
    padding: 0.4em 1.5em;
    position: relative;
    text-align: left;
    width: 100%;
    outline: none;
    border: 2px outset;
    border-width: 2px 0;
  }
  .yancy-accordion > .accordion-panel {
    flex: 0 1 100%;
  }
  .yancy-accordion > .accordion-panel[hidden] {
    display: none;
  }
  .main-container {
    width: 100%;
    height: 100%;
  }
</style>
