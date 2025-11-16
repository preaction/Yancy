<script lang="ts">
  import { onMount } from "svelte";

  type YancyList<T> = {
    items: T[];
    offset: number;
    total: number;
  };
  type Page = {
    pattern: string;
    name: string;
  };

  let pages: Page[];
  onMount(async () => {
    const res = await fetch("./api/pages");
    const list = (await res.json()) as YancyList<Page>;
    pages = list.items.sort((a, b) =>
      a.pattern < b.pattern ? -1 : a.pattern === b.pattern ? 0 : 1,
    );
  });

  // XXX: Need to arrange the routes into a tree?
</script>

<ul>
  {#each pages as page}
    <li><span>{page.pattern}</span> <span>{page.name}</span></li>
  {/each}
</ul>

<style>
  ul {
    margin: 0;
    padding: 0;
    width: 100%;
  }
  li {
    margin: 0;
    padding: 0.2em 0.8em;
    display: flex;
    flex-flow: row wrap;
    justify-content: space-between;
  }
</style>
