<script lang="ts">
  import ContentTree from "./content-tree.svelte";
  import ContentEditor from "./content-editor.svelte";
</script>

<div class="yancy-editor">
  <nav class="yancy-accordion">
    <h2 id="content-tree-button">
      <button aria-controls="content-tree" aria-expanded="true">Content</button>
    </h2>
    <section
      id="content-tree"
      class="accordion-panel"
      aria-labelledby="content-tree-button"
    >
      <ContentTree></ContentTree>
    </section>
    <h2 id="database-button">
      <button aria-controls="database-list" aria-expanded="false"
        >Database</button
      >
    </h2>
    <ul id="database-list" class="accordion-panel" hidden></ul>
  </nav>
  <main>
    <div class="main-container">
      <ContentEditor></ContentEditor>
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
  .yancy-editor > nav {
    flex: 0 1 20%;
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
