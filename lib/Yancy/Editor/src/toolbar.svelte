<div class="toolbar"></div>

<style>
  .toolbar {
    width: 100%;
    height: 2em;
    color: black;
    background: #ccc;
    display: flex;
    align-items: center;
    margin: 0;
    padding: 0;
    border-bottom: 2px outset;
  }
  .toolbar > * {
    display: none;
    margin: 0.2em;
  }
  .toolbar > *.show {
    display: inline-block;
  }
  .toolbar + * {
    margin-top: 2em;
  }
</style>
